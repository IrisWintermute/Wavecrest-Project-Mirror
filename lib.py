
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
        if no_reassignments: return data_array, centroids

        # calculate new centroid coordinates
        for i, _ in enumerate(centroids):
            owned_records = [record for record in data_array if record[-1] == i]
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
    return sum([abs(centroid[i] - attribute) ** 2 for i, attribute in enumerate(record)]) ** 0.5

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
def optimal_k_decision(clustered_data: list[list[float]], centroids: list[list[float]]) -> float:
    vectors = len(clustered_data) * len(clustered_data[0])
    clusters = len(centroids)
    overall_centroid = average(centroids)
    # calculate between-cluster sum of squares
    bcss = 0
    for i, centroid in enumerate(centroids):
        vectors_in_centroid = len([vector for vector in clustered_data if vector[-1] == i]) 
        bcss += vectors_in_centroid * (distance_to_centroid(centroid, overall_centroid) ** 2)
    # calculate within-cluster sum of squares
    wcss = 0
    for i, centroid in enumerate(centroids):
        vectors_in_centroid = [vector for vector in clustered_data if vector[-1] == i]
        wcss += [distance_to_centroid(vec, centroid) ** 2 for vec in vectors_in_centroid]
    # calculate Calinski–Harabasz (CH) index
    return bcss * (vectors - clusters) / (wcss * (clusters - 1))
    


def preprocess(record: list[str]) -> list[int]:
    # truncate and expand record attributes
    with open('attributes.txt') as a, open('persistent_attributes.txt') as b:
        attributes, persist = a.read().split(','), b.read().split(',')
    preprocessed_record = []
    for i, attribute in enumerate(attributes):
        # enrich, truncate and translate CDR data
        match attribute:
            
            #case "Cust. EP IP" | "Prov. EP IP":
                #ip_data = extract_ip_data(record[i])
                #preprocessed_record.extend(ip_data)

            case "EG Duration (min)":
                difference = record[i] - record[i + 1]
                preprocessed_record.append(difference)

            case "IG Setup Time":
                time = record[i].split(" ")[2].split(":")
                time_seconds = time[0] * 3600 + time[1] * 60 + time[2]
                preprocessed_record.append(time_seconds)
        
            case "IG Packet Recieved":
                difference = record[i + 3] - record[i]
                preprocessed_record.append(time_seconds)

            case "EG Packet Recieved":
                difference = record[i + 1] - record[i]
                preprocessed_record.append(time_seconds)

            case attribute if attribute in persist:
                preprocessed_record.append(record[i])
    return preprocessed_record

def vectorise(data_array: list[list[str]]) -> list[list[int]]:
    # [naive general solution] Convert each record entry to a numeric representation
    len_vec = len(data_array[0])
    vector_array = [[0] * len_vec] * len(data_array)
    for i in range(len_vec):
        values = []
        count = 0

        for j, record in enumerate(data_array):
            if type(record[i]) == int:
                vector_array[j][i] = record[i]
            elif record[i] in values:
                vector_array[j][i] = count
            else:
                values.append(record[i])
                count += 1
                vector_array[j][i] = count

        with open("values_dump.txt", "a") as f:
            values.insert(0, f"Values for attribute at index {i}: \n")
            values_to_write = "\n".join(values)
            f.write(values_to_write)
    return vector_array

def normalise(vector_array: list[list[int]]) -> list[list[float]]:
    # normalise each vector to have a length of 1
    for vector in vector_array:
        length = sum([val * 2 for val in vector]) ** 0.5
        for attribute in vector:
            attribute /= length
    return vector_array
    
""" 
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
 """