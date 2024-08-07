
# ||control flow of clustering process||
from lib import *
import numpy as np
import sys
import time


# @profile
def main(plot = 0, mxg = 0, start = 0, end = 0, step = 0):
    """Runs clustering operation."""
    # get_latest_data()

    if mxg == 0:
        mxg = sys.argv[2]
    mx = int(float(mxg) * 1024**3)
    # bring data -2D CSV array- into scope
    # size = os.path.getsize("main/data/cdr.csv")
    # filestep = size // mx if size // mx >= 1 else 1
    with open("main/data/cdr.csv", "r", encoding="utf-8") as f:
            # systematic sampling of dataset
            # csv_list = f.readlines()[::filestep]
            csv_list = f.readlines(mx)
    print(f"CDR data ({len(csv_list)} records) loaded.")

    # data in csv has row length of 129

    counter_start = time.perf_counter()
    csv_nested_list = list(map(to_record, csv_list))
    counter_stop = time.perf_counter()
    print(f"mapping csv list took {counter_stop - counter_start:.2f} seconds")

    del csv_list

    counter_start = time.perf_counter()
    data_array = np.array(csv_nested_list, dtype=object)
    counter_stop = time.perf_counter()
    print(f"converting list to array took {counter_stop - counter_start:.2f} seconds")

    del csv_nested_list

    # enrich and truncate records to optimise for clustering and fraud detection

    counter_start = time.perf_counter()
    data_array_pruned = prune_attrs(data_array)
    counter_stop = time.perf_counter()
    print(f"prune_attrs took {counter_stop - counter_start:.2f} seconds")
    data_array

    counter_start = time.perf_counter()
    data_array_preprocessed = np.apply_along_axis(preprocess_n, 0, data_array_pruned)
    counter_stop = time.perf_counter()
    print(f"data_array_preprocessed took {counter_stop - counter_start:.2f} seconds")
    del data_array_pruned

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

    if start == 0:
        start = int(sys.argv[3])
    if end == 0: 
        end = int(sys.argv[4])
    
    t = lambda a: np.array([a]).T
    cluster_data = (None, None, 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step 0...")
    graph_data = []

    for k in range(start, end + 1):
        k, o_array, centroids = kmeans(k, vector_array_n)
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
        print("Saving data samples from each cluster...")
        mx = np.max(o_array)
        with open("main/data/dump.txt", "w") as f:
            for i in range(int(mx) + 1):
                for j in range(25):
                    record = data_array[o_array == i][j]
                    f.write(",".join([str(i)] + record.tolist()) + "\n")
        print("Saving cluster features...")
        save_clustering_parameters(cluster_data[1], vector_array_n, o_array, 3, 1)
        test_assignments(vector_array_n, o_array, 3, 3, 1)
        
        # a, b, _ = optimal_ab_decision(vector_array_n, o_array, 5, 5)
        
        # save_clustering_parameters(cluster_data[1], vector_array_n, o_array, a, b)




if __name__ == "__main__":
    if len(sys.argv) >= 5:
        plot_data = sys.argv[1]
        main(plot_data)
    else:
        print("Error. When running as file, four input arguments are expected.")
        print("python3 flow.py (Data routing argument) (data set size) (start of k range) (end of k range)")