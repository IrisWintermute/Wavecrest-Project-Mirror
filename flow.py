
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *

# instance recieves command to process data

def main():
    mx = int(input("Enter memory limit (bytes): "))
    # bring data -2D CSV array- into scope
    with open("data/cdr.csv", "r") as f:
        data_csv = f.readlines(mx)
    print(f"CDR data ({len(data_csv)} lines) loaded.")

    data_array = [record.split(",") for record in data_csv]

    # enrich and truncate records to optimise for clustering and fraud detection
    data_array_preprocessed = [preprocess(record) for record in data_array]
    print("Data preprocessed.")

    data_array_preprocessed = diagonal_mirror(data_array_preprocessed)

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    vector_array = vectorise(data_array_preprocessed)
    print("Data vectorised.")

    vector_array_n = normalise(vector_array)
    print("Data normalised.")

    vector_array_n = diagonal_mirror(vector_array_n)
        
    k_range = (90, 110, 2)
    start, end, step = k_range
    clustered_data_optimal = ([], 0, start)
    print(f"Searching for optimal clustering in range {start}-{end} with step {step}...")
    for k in range(start, end + 1, step):
        # run k-means clustering algorithm with vectorised data
        clustered_data, centroids = kmeans(k, vector_array_n)
        # select optimal k
        ch_index = optimal_k_decision(clustered_data, centroids)
        print(f"Evaluated data set with {k} clusters.")
        if ch_index > clustered_data_optimal[1]:
            clustered_data_optimal = (clustered_data, ch_index, k)
    print(f"Range searched. Optimal clustering found with {clustered_data_optimal[2]} (CH index of {clustered_data_optimal[1]}).")

    with open("output_data.txt", "w") as f:
        records = [",".join([str(attr) for attr in vector]) for vector in clustered_data_optimal[0]]
        data = "\n".join(records)
        f.write(data)
    print("Clustered data written to output_data.txt.")

if __name__ == "__main__":
    main()
