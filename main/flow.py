
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *
import matplotlib.pyplot as plt
import numpy as np
from memory_profiler import profile
import os
from multiprocessing import Pool, Lock
import sys

# instance recieves command to process data
@profile
def main(plot = 0):
    if len(sys.argv) > 2:
        mxg = sys.argv[2]
    else:
        mxg = input("Enter memory limit (GB): ")

    vector_array_n = get_preprocessed_data(mxg)

    if plot == 1:
        # plot_single_data(data_array_preprocessed, vector_array_n, 3)
        # plot_data(vector_array_n)
        plot_data_3d(vector_array_n)
        return 0

    if len(sys.argv) >= 5:
        start = int(sys.argv[3]) 
        end = int(sys.argv[4])
        step = int(sys.argv[5])
    else:
        while True:
            start = int(input("Enter start of k search range: "))
            if start < len(vector_array_n): break
        while True:
            end = int(input("Enter end of k search range: "))
            if end > start and end < len(vector_array_n): break
        while True:
            step = int(input("Enter step of k search range: "))
            if (end - start) >= step: break

    cluster_data = (None, None, 0, start)
    graph_data = []
    cores = os.cpu_count()
    lock = Lock()
    print(f"Searching for optimal clustering in range {start}-{end} with step {step}...")
    k_range_wrap = [(k, vector_array_n) for k in range(start, end + 1, step)]

    with Pool(processes=cores) as p:
        for k, clustered_data, centroids in p.imap_unordered(kmeans, k_range_wrap):
            with lock:
                ch_index = optimal_k_decision(clustered_data, centroids)
                graph_data.append(np.array([k, ch_index]))
                print(f"Evaluated data set with {k} clusters.")
                if ch_index > cluster_data[2]:
                    cluster_data = (clustered_data, centroids, ch_index, k)
    print(f"Range searched. Optimal clustering found with {cluster_data[3]} (CH index of {cluster_data[2]}).")

    get_last = lambda v: v[-1]
    o_array = np.apply_along_axis(get_last, 1, cluster_data[0])

    if plot == 2:
        # plot_clustered_data(cluster_data[0])
        # plot_clustered_data_3d(cluster_data[0])
        # plot_clustering_range(graph_data, len(cluster_data[0]))
        plot_clustered_data_batch(cluster_data[0])

        with open("clustering_stats.txt", "a") as f:
            sizes = [str(cluster_data[0][o_array == i].shape[0]) for i in range(len(cluster_data[1]))]
            f.write(str(cluster_data[0].shape[0]) + "," + ",".join(sizes) + "\n")
        return 0

    if plot == 3:
        with open("main/data/output_data_vectorised.txt", "w") as f:
            records = [",".join([str(attr) for attr in vector]) for vector in cluster_data[0]]
            f.writelines(records)
        print("Clustered and vectorised data written to output_data_vectorised.txt.")

        data_array = get_raw_data(mxg)
        with open("main/data/output_data.txt", "w") as f:
            o_array = o_array.astype(str)
            records = [",".join([str(attr) for attr in vector[:128]]) for vector in data_array]
            for i, v in enumerate(o_array):
                records[i] += (',"",' + str(v))
            f.writelines(records)
        print("Clustered data written to output_data.txt.")

    if plot == 0:
        save_clustering_parameters(cluster_data[1], cluster_data[0], o_array)


if __name__ == "__main__":
    if (len(sys.argv) > 1):
        plot_data = sys.argv[1]
    else:
        plot_data = 0
    main(plot_data)
