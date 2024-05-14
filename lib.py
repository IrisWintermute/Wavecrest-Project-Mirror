
# ||function library for k-means program||

# cluster data using k-means algorithm
def kmeans(k, data_array):
    # use kmeans++ to get initial centroid coordinates
    centroids = k_means_pp(k, data_array)
    centroids_new = centroids

    while True:
        no_reassignments = True
        # assign each data point to closest centroid
        for record in data_array:
            distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
            (_, closest_centroid) = distances.sort(lambda d, _: d)[0]
            if record[-1] != closest_centroid: 
                record[-1] = closest_centroid
                no_reassignments = False

        # stop algorithm when no records are reassigned
        if no_reassignments: return centroids

        # calculate new centroid coordinates
        for i in range(centroids):
            owned_records = [record.pop() for record in data_array if record[-1] == i]
            centroids_new[i] = average(owned_records)

        centroids = centroids_new

# get data from S3 bucket
def get_data():
    pass

# randomly select initial centroids from unclustered data
def k_means_pp(k, data):
    pass

# calculate distance between record and centroid
def distance_to_centroid(record, centroid):
    pass

# reduce list of input vectors into a single vector representing the average of input vectors
def average(records):
    pass

# return optimal k and clustered data from kmeans(k, data)
def optimal_k_decision(clustered_data_list):
    pass

# parse non-numeric data into a form that enables vector operations to be performed with data
def vectorise(attribute):
    pass