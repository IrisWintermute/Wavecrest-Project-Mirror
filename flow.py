
# ||control flow of k-means program||
# ||running inside an AWS EC2 instance||

# instance recieves command to process data

# instance uses batch or scan to pull CDR data from S3 input bucket

# bring data -2D CSV array- into scope

# (vectorise) convert each record to array with uniform numerical type - data stored as nested array

# run k-means clustering algorithm with vectorised data

    # use kmeans++ to get initial centroid coordinates

    # assign each data point to closest centroid

    # calculate new centroid coordinates

    # repeat 19 and 21 until no reassignments take place

# select optimal k (decision to make on method - depends on data)

# push clustered data to S3 output bucket
