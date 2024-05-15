
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||
from lib import *

attribute_map = {
    0 : "country",
    1 : "region",
    2 : "group",
}
max_k = 20

# instance recieves command to process data

# instance downloads CDR data object from S3 input bucket

# bring data -2D CSV array- into scope
data_csv = get_data()

# (vectorise) convert each record to array with uniform numerical type - data stored as nested array
data_array = [[attribute for attribute in record.split(",")].append(0) for record in data_csv.split("\n")]

data_array_univ = []
for record in data_array:
    record_univ = []
    for i, attribute in enumerate(record):
        record_univ.append(vectorise(attribute, attribute_map.get(i)) if attribute_map.get(i) else attribute)
    data_array_univ.append(record_univ)
    

clustered_data_list = []
for k in range(1, max_k):
    # run k-means clustering algorithm with vectorised data
    clustered_data_list.append(kmeans(k, data_array_univ))

# select optimal k (decision to make on method - depends on data)
(k_optimal, clustered_data) = optimal_k_decision(clustered_data_list)

# push clustered data to S3 output bucket
