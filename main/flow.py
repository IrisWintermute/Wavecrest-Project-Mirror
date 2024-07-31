
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *
import numpy as np
from memory_profiler import profile
import os
from multiprocessing import Pool, Lock
import sys
import time

# instance recieves command to process data
# @profile
def main(plot = 0, mxg = 0, start = 0, end = 0, step = 0):
    """Runs clustering operation."""
    get_latest_data()

    if mxg:
        pass
    elif len(sys.argv) > 2:
        mxg = sys.argv[2]
    else:
        mxg = input("Enter memory limit (GB): ")
    mx = int(float(mxg) * 1024**3)
    # bring data -2D CSV array- into scope
    # size = os.path.getsize("main/data/cdr.csv")
    # filestep = size // mx if size // mx >= 1 else 1
    with open("main/data/cdr.csv", "r", encoding="utf-8") as f:
            # systematic sampling of dataset
            # csv_list_r = f.readlines(size)
            csv_list = f.readlines(mx)
            # del csv_list_r
            # del mx
    print(f"CDR data ({len(csv_list)} records) loaded.")

    with open("main/data/plot.txt", "w") as f:
        f.write("")

    # data in csv has row length of 129
    # counter_start = time.perf_counter()
    # to_record = lambda s: sanitise_string(s).split(",")[:25]
    # counter_stop = time.perf_counter()
    # print(f"sanitise string took {counter_stop - counter_start} seconds")

    counter_start = time.perf_counter()
    csv_nested_list = list(map(to_record, csv_list))
    counter_stop = time.perf_counter()
    print(f"mapping csv list took {counter_stop - counter_start} seconds")

    # counter_start = time.perf_counter()
    # data_array_r = np.array([str(l.split(",")) for l in csv_list], dtype=object)
    # data_array_r = data_array_r[:, :25]
    # data_array = to_record(data_array_r)
    # del data_array_r
    # counter_stop = time.perf_counter()
    # print(f"generating data_array took {counter_stop - counter_start} seconds")

    del csv_list

    counter_start = time.perf_counter()
    data_array = np.array(csv_nested_list, dtype=object)
    counter_stop = time.perf_counter()
    print(f"converting list to array took {counter_stop - counter_start} seconds")

    del csv_nested_list

    # enrich and truncate records to optimise for clustering and fraud detection

    # data_array_preprocessed = np.apply_along_axis(preprocess, 1, data_array)
    # del data_array
    # print("Data preprocessed.")

    counter_start = time.perf_counter()
    data_array_loaded = load_attrs(data_array)
    counter_stop = time.perf_counter()
    print(f"load_attrs took {counter_stop - counter_start} seconds")
    data_array

    counter_start = time.perf_counter()
    data_array_preprocessed = np.apply_along_axis(preprocess_n, 0, data_array_loaded)
    counter_stop = time.perf_counter()
    print(f"data_array_preprocessed took {counter_stop - counter_start} seconds")
    del data_array_loaded

    print("Data preprocessed.")

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    with open("main/data/values_dump.txt", "w") as f:
        f.write("")
    vector_array = np.apply_along_axis(vectorise, 0, data_array_preprocessed)
    del data_array_preprocessed
    print("Data vectorised.")  

    save_minmax(vector_array)
    vector_array_n = np.apply_along_axis(normalise, 0, vector_array)
    del vector_array
    print("Data normalised.")

    if plot == 1:
        # plot_single_data(data_array_preprocessed, vector_array_n, 3)
        # plot_data(vector_array_n)
        plot_data_3d(vector_array_n)
        return 0

    if start and end:
        pass
    elif len(sys.argv) >= 5:
        start = int(sys.argv[3]) 
        end = int(sys.argv[4])
        # step = int(sys.argv[5])
    else:
        print(sys.argv)
        while True:
            start = int(input("Enter start of k search range: "))
            if start < len(vector_array_n): break
        while True:
            end = int(input("Enter end of k search range: "))
            if end < len(vector_array_n): break
        # while True:
        #     step = int(input("Enter step of k search range: "))
        #     if (end - start) >= step: break
    
    t = lambda a: np.array([a]).T
    cluster_data = (None, None, 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step 0...")
    graph_data = []
    # cores = os.cpu_count()
    # lock = Lock()
    # k_range_wrap = [(k, vector_array_n) for k in range(start, end + 1)]
    # with Pool(processes=cores) as p:
    #     for k, o_array, centroids in p.imap_unordered(kmeans, k_range_wrap):
    #         with lock:
    #             ch_index = optimal_k_decision(vector_array_n, centroids, o_array)
    #             graph_data.append(np.array([k, ch_index]))
    #             print(f"Evaluated data set with {k} clusters.")
    #             if ch_index > cluster_data[2]:
    #                 cluster_data = (o_array, centroids, ch_index, k)

    for k in range(start, end + 1):
        k, o_array, centroids = kmeans((k, vector_array_n))
        ch_index = optimal_k_decision(vector_array_n, centroids, o_array)
        graph_data.append(np.array([k, ch_index]))
        print(f"Evaluated data set with {k} clusters.")
        if ch_index > cluster_data[2]:
            cluster_data = (o_array, centroids, ch_index, k)
    print(f"Range searched. Optimal clustering found with {cluster_data[3]} (CH index of {cluster_data[2]}).")



    if plot == 2:
        # plot_clustered_data(cluster_data[0])
        # plot_clustered_data_3d(cluster_data[0])
        plot_clustering_range(graph_data, len(cluster_data[0]))
        plot_clustered_data_batch(cluster_data[0])

        with open("main/data/clustering_stats.txt.txt", "a") as f:
            sizes = [str(cluster_data[0][o_array == i].shape[0]) for i in range(len(cluster_data[1]))]
            f.write(str(cluster_data[0].shape[0]) + "," + ",".join(sizes) + "\n")
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

    o_array = cluster_data[0]

    if plot == 3:
        with open("main/data/output_data_vectorised.txt", "w") as f:
            records = [",".join([str(attr) for attr in vector]) for vector in np.concatenate((vector_array_n, t(o_array)), axis=1)]
            f.writelines(records)
        print("Clustered and vectorised data written to output_data_vectorised.txt.")

        with open("main/data/output_data.txt", "w") as f:
            o_array = o_array.astype(str)
            records = [",".join([str(attr) for attr in vector[:128]]) for vector in data_array]
            for i, v in enumerate(o_array):
                records[i] += (',"",' + str(v))
            f.writelines(records)
        print("Clustered data written to output_data.txt.")

    if plot == 0:
        mx = np.max(o_array)
        with open("main/dump.txt", "w") as f:
            for i in range(int(mx) + 1):
                record = data_array[o_array == i][0]
                f.write(",".join(record.tolist()))
                f.write("\n")
        save_clustering_parameters(cluster_data[1], vector_array_n, o_array, 1, 1)
        
        a, b, _ = optimal_ab_decision(vector_array_n, o_array, 5, 5)
        
        save_clustering_parameters(cluster_data[1], vector_array_n, o_array, a, b)




if __name__ == "__main__":
    counter_start = time.perf_counter()
    if (len(sys.argv) > 1):
        plot_data = sys.argv[1]
    else:
        plot_data = 0
    main(plot_data)
    counter_stop = time.perf_counter()
    print(f"this took {counter_stop - counter_start}")
