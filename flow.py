
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *
import matplotlib.pyplot as plt

# instance recieves command to process data

def main():
    mx = int(float(input("Enter memory limit (MB): ")) * 1024**2)
    # bring data -2D CSV array- into scope
    with open("data/cdr.csv", "r") as f:
        data_csv = f.readlines(mx)
    print(f"CDR data ({len(data_csv)} records) loaded.")

    data_array = [record.split(",") for record in data_csv]

    # enrich and truncate records to optimise for clustering and fraud detection
    data_array_preprocessed = [preprocess(record) for record in data_array]
    print("Data preprocessed.")

    data_array_preprocessed = diagonal_mirror_mv(data_array_preprocessed)

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    vector_array = vectorise(data_array_preprocessed)
    print("Data vectorised.")

    vector_array_n = normalise(vector_array)
    print("Data normalised.")

    vector_array_n = diagonal_mirror_mv(vector_array_n)

    while True:
        start = int(input("Enter start of k search range: "))
        if start < len(vector_array_n): break
    while True:
        end = int(input("Enter end of k search range: "))
        if end > start and end < len(vector_array_n): break
    while True:
        step = int(input("Enter step of k search range: "))
        if (end - start) // step > 1: break

    clustered_data_optimal = ([], 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step {step}...")
    k_range = [k for k in range(start, end + 1, step)]
    ch_indexes = []
    for k in k_range:
        # run k-means clustering algorithm with vectorised data
        clustered_data, centroids = kmeans(k, vector_array_n)
        # select optimal k
        ch_index = optimal_k_decision(clustered_data, centroids)
        ch_indexes.append(ch_index)
        print(f"Evaluated data set with {k} clusters.")
        if ch_index > clustered_data_optimal[1]:
            clustered_data_optimal = (clustered_data, ch_index, k)
    print(f"Range searched. Optimal clustering found with {clustered_data_optimal[2]} (CH index of {clustered_data_optimal[1]}).")

    plt.plot(k_range, ch_indexes)
    plt.xlabel("Number of clusters")
    plt.ylabel("CH Index")
    plt.title(f"CH index evaluation of clustering for set of {len(vector_array_n)} records.")
    plt.savefig()

    for i, vec in enumerate(clustered_data_optimal[0]):
        data_array[i].append(vec[-1])

    with open("output_data.txt", "w") as f:
        records = [",".join([str(attr) for attr in vector]) for vector in data_array]
        data = "\n".join(records)
        f.write(data)
    print("Clustered data written to output_data.txt.")

if __name__ == "__main__":
    main()
