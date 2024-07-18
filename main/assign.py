import numpy as np
from lib import *


with open("incoming_records.txt", "r") as f:
    records_raw = f.readlines()
    preprocessed_records = list(map(preprocess_single, records_raw))

with open("clustering_parameters.txt", "r") as f:
    to_arr = lambda l_list: np.array([[float(v) for v in l.split(",")] for l in l_list.split("\n")])
    out = f.readlines()
    (centroids, stdevs) = tuple([to_arr(out[:len(out) // 2]), to_arr(out[len(out) // 2 + 1:])])

assigned_records = np.array(list(map(assign_cluster, preprocessed_records)))