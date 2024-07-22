import numpy as np
from lib import *

def main():
    raw_record = get_record()

    # needs to use values_dump generated from dataset preprocessing
    preprocessed_record = preprocess_incoming_record(raw_record)

    (centroids, stdevs) = get_clustering_parameters()

    # cluster indexes as keys, fraud ratings as values
    fraud_hash = rate_cluster_fraud(stdevs)

    assigned_record = assign_cluster(preprocessed_record, centroids, stdevs)

    rating = fraud_hash.get(assigned_record[-1])

    print(f"Record assigned to cluster with index {assigned_record[-1]} with fraudulence rating of {rating} / 1.0")
    return rating

if __name__ == "__main__":
    main()