import numpy as np
from lib import *


with open("incoming_records.txt", "r") as f:
#     records_raw = f.readlines()
#     preprocessed_records = list(map(preprocess_single, records_raw))
    preprocessed_records = f.readlines()

(centroids, stdevs) = get_clustering_parameters()

assigned_records = np.array([assign_cluster(record, centroids, stdevs) for record in preprocessed_records])

