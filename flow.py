
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *

# instance recieves command to process data

# instance downloads CDR data object from S3 input bucket

# bring data -2D CSV array- into scope
with open("./data/" + cdr_filename, "r") as f:
    data_csv = f.read()

# (vectorise) convert each record to array with uniform numerical type - data stored as nested array
data_array = [[attribute for attribute in record.split(",")].append(0) for record in data_csv.split("\n")]

data_array_preprocessed = [preprocess(record) for record in data_array]

vector_array = vectorise(data_array_preprocessed)

vector_array_n = [normalise(vector) for vector in vector_array]
    
max_k = 20
clustered_data_optimal = ([], 0)
for k in range(1, max_k):
    # run k-means clustering algorithm with vectorised data
    clustered_data, centroids = kmeans(k, vector_array_n)
    # select optimal k
    ch_index = optimal_k_decision(clustered_data, centroids)
    if ch_index > clustered_data_optimal[1]:
        clustered_data_optimal = (clustered_data, ch_index)


# push clustered data to S3 output bucket
