
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *
import matplotlib.pyplot as plt
import numpy as np
from memory_profiler import profile
import os
from multiprocessing import Pool, Lock

# instance recieves command to process data
#@profile
def main():
    # mx = int(float(input("Enter memory limit (GB): ")) * 1024**3)
    # bring data -2D CSV array- into scope
    with open("main/data/cdr.csv", "r") as f:
            csv_list = f.readlines(int(0.00007 * 1024**3))
    print(f"CDR data ({len(csv_list)} records) loaded.")

    # data_array = np.asarray([np.asarray(sanitise_string(record).split(","), dtype=object) for record in csv_list], dtype=np.ndarray)
    to_record = lambda s: sanitise_string(str(s)).split(",")[:129]
    # data_array = np.asarray(list(map(to_record, csv_list)))
    csv_nested_list = list(map(to_record, csv_list))
    del csv_list
    data_array = np.array(csv_nested_list, dtype=object)
    del csv_nested_list

    for array in data_array:
        print(array)

    # enrich and truncate records to optimise for clustering and fraud detection
    data_array_preprocessed = np.apply_along_axis(preprocess, 1, data_array)
    print("Data preprocessed.")

    for array in data_array_preprocessed:
        print(array)

    #data_array_preprocessed = diagonal_mirror(data_array_preprocessed)

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    with open("main/data/values_dump.txt", "w") as f:
        f.write("")
    vector_array = np.apply_along_axis(vectorise, 0, data_array_preprocessed)
    del data_array_preprocessed
    print("Data vectorised.")  

    for array in vector_array:
        print(array)

    vector_array_n = np.apply_along_axis(normalise, 0, vector_array)
    del vector_array
    print("Data normalised.")

    #vector_array_n = diagonal_mirror(vector_array_n)

    while True:
        start = int(input("Enter start of k search range: "))
        if start < len(vector_array_n): break
    while True:
        end = int(input("Enter end of k search range: "))
        if end > start and end < len(vector_array_n): break
    while True:
        step = int(input("Enter step of k search range: "))
        if (end - start) >= step: break

    # with open("main/data/plot.txt", "w") as f:
    #     f.write("")

    clustered_data_optimal = (None, 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step {step}...")
    k_range_wrap = [(k, vector_array_n) for k in range(start, end + 1, step)]
    graph_data = []
    cores = os.cpu_count()
    lock = Lock()
    with Pool(processes=cores) as p:
        for k, clustered_data, centroids in p.imap_unordered(kmeans, k_range_wrap):
            with lock:
                ch_index = optimal_k_decision(clustered_data, centroids)
                graph_data.append(np.array([k, ch_index]))
                print(f"Evaluated data set with {k} clusters.")
                if ch_index > clustered_data_optimal[1]:
                    clustered_data_optimal = (clustered_data, ch_index, k)
    print(f"Range searched. Optimal clustering found with {clustered_data_optimal[2]} (CH index of {clustered_data_optimal[1]}).")

    """ for k in k_range:
        # run k-means clustering algorithm with vectorised data
        clustered_data, centroids = kmeans(k, vector_array_n)
        # select optimal k
        ch_index = optimal_k_decision(clustered_data, centroids)
        ch_indexes.append(ch_index)
        print(f"Evaluated data set with {k} clusters.")
        if ch_index > clustered_data_optimal[1]:
            clustered_data_optimal = (clustered_data, ch_index, k)"""

    graph_data = sorted(graph_data, key=lambda x: x[0])
    graph_array = np.stack(graph_data, axis=0).T
    (x, y) = tuple(np.split(graph_array, 2, axis=0))
    # with open("main/data/plot.txt", "r") as f:
    #     y = f.read().split(",")[1:]
    # y = [float(v) for v in y]
    # x = [v for v in range(start, end + 1, step)]
    plt.plot(x[0], y[0])
    plt.xlabel("Number of clusters")
    plt.ylabel("CH Index")
    plt.title(f"CH index evaluation of clustering for set of {len(vector_array_n)} records.")
    plt.savefig("main/data/savefig.png")
    # plt.plot(x, y, "r-")
    # plt.xlabel("Number of clusters")
    # plt.ylabel("Execution time (s)")
    # plt.title(f"Execution time evalutation for kmeans() for {len(vector_array_n)} records.")
    # plt.savefig("main/data/savefig.png")
    # plot_data(vector_array_n)

    # for i, vec in enumerate(clustered_data_optimal[0]):
        # np.append(data_array[i], vec[-1])

    with open("main/data/output_data_vectorised.txt", "w") as f:
        records = [",".join([str(attr) for attr in vector]) for vector in clustered_data_optimal[0]]
        f.writelines(records)
    print("Clustered and vectorised data written to output_data_vectorised.txt.")

    with open("main/data/output_data.txt", "w") as f:
        get_last = lambda v: v[-1]
        o_array = np.apply_along_axis(get_last, 1, clustered_data_optimal[0])
        o_array = o_array.astype(str)
        [print(str(v)) for v in o_array]
        records = [",".join([str(attr) for attr in vector[:128]]) for vector in data_array]
        for i, v in enumerate(o_array):
            records[i] += (',"",' + str(v))
        f.writelines(records)
    print("Clustered data written to output_data.txt.")
    print(records[0])

if __name__ == "__main__":
    main()
