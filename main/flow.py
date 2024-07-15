
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *
import matplotlib.pyplot as plt
import numpy as np
from memory_profiler import profile
import os
from multiprocessing import Pool, Lock

# instance recieves command to process data
def main(plot = 0):
    mx = int(float(input("Enter memory limit (GB): ")) * 1024**3)
    # bring data -2D CSV array- into scope
    size = os.path.getsize("main/data/cdr.csv")
    filestep = size // mx if size // mx >= 1 else 1
    with open("main/data/cdr.csv", "r", encoding="utf-8") as f:
            # systematic sampling of dataset
            csv_list_r = f.readlines(size)
            csv_list = csv_list_r[::filestep]
            del csv_list_r
            del mx
    print(f"CDR data ({len(csv_list)} records) loaded.")

    with open("main/data/plot.txt", "w") as f:
        f.write("")

    # data in csv has row length of 129
    to_record = lambda s: sanitise_string(str(s)).split(",")[:25]
    csv_nested_list = list(map(to_record, csv_list))
    del csv_list, to_record
    data_array = np.array(csv_nested_list, dtype=object)
    del csv_nested_list

    # enrich and truncate records to optimise for clustering and fraud detection

    # data_array_preprocessed = np.apply_along_axis(preprocess, 1, data_array)
    # del data_array
    # print("Data preprocessed.")

    data_array_loaded = load_attrs(data_array)
    del data_array
    data_array_preprocessed = np.apply_along_axis(preprocess_n, 0, data_array_loaded)
    del data_array_loaded
    print("Data preprocessed.")

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    with open("main/data/values_dump.txt", "w") as f:
        f.write("")
    vector_array = np.apply_along_axis(vectorise, 0, data_array_preprocessed)
    del data_array_preprocessed
    print("Data vectorised.")  

    vector_array_n = np.apply_along_axis(normalise, 0, vector_array)
    del vector_array
    print("Data normalised.")

    if plot == 1:
        # plot_single_data(data_array_preprocessed, vector_array_n, 3)
        # plot_data(vector_array_n)
        plot_data_3d(vector_array_n)
        return 0

    while True:
        start = int(input("Enter start of k search range: "))
        if start < len(vector_array_n): break
    while True:
        end = int(input("Enter end of k search range: "))
        if end > start and end < len(vector_array_n): break
    while True:
        step = int(input("Enter step of k search range: "))
        if (end - start) >= step: break

    clustered_data_optimal = (None, None, 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step {step}...")
    k_range_wrap = [(k, vector_array_n) for k in range(start, end + 1, step)]
    del vector_array_n
    graph_data = []
    cores = os.cpu_count()
    lock = Lock()
    with Pool(processes=cores) as p:
        for k, clustered_data, centroids in p.imap_unordered(kmeans, k_range_wrap):
            with lock:
                ch_index = optimal_k_decision(clustered_data, centroids)
                graph_data.append(np.array([k, ch_index]))
                print(f"Evaluated data set with {k} clusters.")
                if ch_index > clustered_data_optimal[2]:
                    clustered_data_optimal = (clustered_data, centroids, ch_index, k)
    print(f"Range searched. Optimal clustering found with {clustered_data_optimal[3]} (CH index of {clustered_data_optimal[2]}).")
    with open("clustering_stats.txt", "w") as f:
        get_last = lambda v: v[-1]
        o_array = np.apply_along_axis(get_last, 1, clustered_data_optimal[0])
        for i, centroid in enumerate(clustered_data_optimal[1]):
            f.write(f"Centroid {i}:")
            f.write([f"{v:.6f}" for v in centroid])
            f.write(f"count: {clustered_data_optimal[0][o_array == i]}")

    if plot == 2:
        # plot_clustered_data(clustered_data_optimal[0])
        # plot_clustered_data_3d(clustered_data_optimal[0])
        # plot_clustering_range(graph_data, len(clustered_data_optimal[0]))
        plot_clustered_data_batch(clustered_data_optimal[0])
        return 0

    # with open("main/data/plot.txt", "r") as f:
    #     y = f.read().split(",")[1:]
    # y = [float(v) for v in y]
    # x = [v for v in range(start, end + 1, step)]
    # plt.plot(x, y, "r-")
    # plt.xlabel("Number of clusters")
    # plt.ylabel("Execution time (s)")
    # plt.title(f"Execution time evalutation for kmeans() for {len(vector_array_n)} records.")
    # plt.savefig("main/data/savefig.png")

    if plot == 0:
        with open("main/data/output_data_vectorised.txt", "w") as f:
            records = [",".join([str(attr) for attr in vector]) for vector in clustered_data_optimal[0]]
            f.writelines(records)
        print("Clustered and vectorised data written to output_data_vectorised.txt.")

        with open("main/data/output_data.txt", "w") as f:
            get_last = lambda v: v[-1]
            o_array = np.apply_along_axis(get_last, 1, clustered_data_optimal[0])
            o_array = o_array.astype(str)
            records = [",".join([str(attr) for attr in vector[:128]]) for vector in data_array]
            for i, v in enumerate(o_array):
                records[i] += (',"",' + str(v))
            f.writelines(records)
        print("Clustered data written to output_data.txt.")

if __name__ == "__main__":
    plot_data = 2
    main(plot_data)
