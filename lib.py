
# ||function library for k-means program||
import random
import requests

# cluster data using k-means algorithm
def kmeans(k: int, data_array: list[list[int]]) -> list[list[int]]:
    # use kmeans++ to get initial centroid coordinates
    centroids = k_means_pp(k, data_array)
    centroids_new = centroids

    while True:
        no_reassignments = True
        # assign each data point to closest centroid
        for record in data_array:
            (_, closest_centroid_index) = get_closest_centroid(record, centroids)
            if record[-1] != closest_centroid_index: 
                record[-1] = closest_centroid_index
                no_reassignments = False

        # stop algorithm when no records are reassigned
        if no_reassignments: return centroids

        # calculate new centroid coordinates
        for i in range(centroids):
            owned_records = [record.pop() for record in data_array if record[-1] == i]
            centroids_new[i] = average(owned_records)

        centroids = centroids_new

# get data from S3 bucket
def get_data() -> str:
    pass

# randomly select initial centroids from unclustered data
def k_means_pp(k: int, data: list[list[int]]) -> list[list[int]]:
    chosen_indexes = [random.randint(0, len(data) - 1)]
    centroids = [data[chosen_indexes[0]]]
    square_distances = {}

    while len(centroids) < k:
        for i, record in enumerate(data):
            if i not in chosen_indexes:
                (dist_to_nearest_centroid, _) = get_closest_centroid(record, centroids)
                square_distances[i] = dist_to_nearest_centroid ** 2

        sum_of_squares = sum(square_distances.values())

        for index, dist in square_distances.items():
            if random.random() < (dist / sum_of_squares):
                centroids.append(data[index])
                break

    return centroids

# calculate distance between record and centroid
def distance_to_centroid(record: list[int], centroid: list[float]) -> float:
    return sum([abs(centroid[i] - attribute) ** 2 for i, attribute in enumerate(record)])

# returns tuple of distance between record and nearest centroid, and index of nearest centroid
def get_closest_centroid(record: list[int], centroids: list[list[float]]) -> tuple[float, int]:
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    return distances.sort(key = lambda d, _: d)[0]

# reduce list of input vectors into a single vector representing the average of input vectors
def average(records: list[list[int]]) -> list[float]:
    sum = [0 for _ in records[0]]
    for record in records:
        for i, attribute in enumerate(record):
            sum[i] += attribute

    return [attr / len(sum) for attr in sum]
    


# return optimal k and clustered data from kmeans(k, data)
def optimal_k_decision(clustered_data_list: list[list[list[int]]]) -> tuple[int, list[list[int]]]:
    pass

# parse non-numeric data into a form that enables vector operations to be performed with data
def vectorise(record: list[str]) -> list[int]:
    with open("attributes.txt", "r") as file:
        attributes = file.read().split(",")
    preprocessed_record = []
    for i, attribute in enumerate(attributes):
        # enrich, truncate and translate CDR data
        if attribute == "Cust. EP IP":
            ip_data = extract_ip_data(record[i])
            preprocessed_record.append(ip_data)

    vector = []
    for attribute in preprocessed_record:
        # map each attribute to a numerical position in the n-dimensional vector space
        pass

    for attribute in preprocessed_record:
        # normalise vector
        pass

    return vector

def extract_ip_data(ip_address: str) -> dict[str]:
    response = requests.get(f'https://ipapi.co/{ip_address}/json/').json()
    data = [
        response.get("city"),
        response.get("region"),
        response.get("country_calling_code"),
        response.get("utc_offset"),
        response.get("currency")
    ]
    return data
