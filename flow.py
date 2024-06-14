
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *

# instance recieves command to process data

# instance downloads CDR data object from S3 input bucket

# bring data -2D CSV array- into scope
with open("data/cdr.csv", "r") as f:
    data_csv = f.readlines()

# (vectorise) convert each record to array with uniform numerical type - data stored as nested array
data_array = [record.split(",") for record in data_csv]

data_array_preprocessed = [preprocess(record) for record in data_array]

data_array_preprocessed = diagonal_mirror(data_array_preprocessed)

vector_array = vectorise(data_array_preprocessed)

vector_array_n = normalise(vector_array)

vector_array_n = diagonal_mirror(vector_array_n)
    
max_k = 200
clustered_data_optimal = ([], 0)
for k in range(2, max_k):
    # run k-means clustering algorithm with vectorised data
    clustered_data, centroids = kmeans(k, vector_array_n)
    # select optimal k
    ch_index = optimal_k_decision(clustered_data, centroids)
    print(k)
    print(ch_index)
    if ch_index > clustered_data_optimal[1]:
        clustered_data_optimal = (clustered_data, ch_index)

with open("output_data.txt", "w") as f:
    records = [",".join([str(attr) for attr in vector]) for vector in clustered_data_optimal[0]]
    data = "\n".join(records)
    f.write(data)
# push clustered data to S3 output bucket
