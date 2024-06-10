
# ||function library for k-means program||
import random
import re
import phonenumbers
import matplotlib.pyplot as plt

# cluster data using k-means algorithm
def kmeans(k: int, data_array: list[list[float]]) -> list[list[float]]:
    # use kmeans++ to get initial centroid coordinates
    centroids = k_means_pp(k, data_array)
    d_plt = diagonal_mirror(data_array)
    c_plt = diagonal_mirror(centroids)
    plt.plot(d_plt[0], d_plt[1], "ro")
    plt.plot(c_plt[0], c_plt[1], "bo")
    plt.show()
    centroids_new = centroids

    while True:
        no_reassignments = True
        # assign each data point to closest centroid
        for record in data_array:
            (_, closest_centroid_index) = get_closest_centroid(record, centroids)
            if record[-1] != closest_centroid_index: 
                record[-1] = closest_centroid_index
                no_reassignments = False

        print([record[-1] for record in data_array])
        print(centroids)
        # stop algorithm when no records are reassigned
        if no_reassignments: return data_array, centroids

        # calculate new centroid coordinates
        for i, _ in enumerate(centroids):
            owned_records = [record for record in data_array if record[-1] == i]
            centroids_new[i] = average(owned_records)

        centroids = centroids_new

# get data from S3 bucket
# when user_data script is run upon EC2 deployment, all data in s3 bucket is synced to ./data repository
# data copied will include CDR and MDL data

# K++ algorithm
# randomly select initial centroids from unclustered data
def k_means_pp(k: int, data: list[list[float]]) -> list[list[float]]:
    chosen_indexes = [random.randint(0, len(data) - 1)]
    centroids = [data[chosen_indexes[0]]]
    square_distances = {}

    while len(centroids) < k:
        for i, record in enumerate(data):
            if i not in chosen_indexes:
                (dist_to_nearest_centroid, _) = get_closest_centroid(record, centroids)
                square_distances[i] = dist_to_nearest_centroid ** 2

        sum_of_squares = sum([v for v in square_distances.values()])

        for index, sq_dist in square_distances.items():
            if random.random() < (sq_dist / sum_of_squares):
                centroids.append(data[index])
                chosen_indexes.append(index)
                break

    return centroids

def distance_to_centroid(record: list[float], centroid: list[float]) -> float:
    # calculate distance between record and centroid
    return sum([abs(centroid[i] - attribute) ** 2 for i, attribute in enumerate(record)]) ** 0.5

def get_closest_centroid(record: list[float], centroids: list[list[float]]) -> tuple[float, int]:
    # returns tuple of distance between record and nearest centroid, and index of nearest centroid
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    # def func(t):
    #     (d, _) = t
    #     return d
    distances.sort()
    return distances[0]

def average(records: list[list[float]]) -> list[float]:
    # reduce list of input vectors into a single vector representing the average of input vectors
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
    
def get_destination(number):
    with open("./data/MDL_160524.csv", "r") as f:
        lines = [(line.split(",")[4], line.split(",")[1]) for line in f.readlines()]
        match = ("", "")
        for (prefix, destination) in lines:
            # check if prefix matches start of number
            # obtain the longest matching prefix - most precise destination
            if re.search(f"^{prefix}", number) and len(match[0]) < len(prefix):
                match = (prefix, destination)
        return match[1]

def get_day_from_date(date):
    # takes date and returns int in range 0-7, corresponding to monday-sunday
    (month, day, year) = tuple([int(val) for val in date.split("/")])
    year += 2000
    if month in [1, 2]:
        month += 12
        year -= 1
    k = year % 100
    j = year // 100
    return (day + ((13 * (month + 1)) // 5) + k + (k // 4) + (j // 4) - (2 * j) - 2) % 7
    
def can_cast_to_int(v: str) -> bool:
    try:
        _ = int(v)
    except ValueError:
        return False
    else:
        return True
    
def diagonal_mirror(nested_list: list[list]) -> list[list]:
    nested_out = [[0 for _ in nested_list] for _ in nested_list[0]]
    for i, list in enumerate(nested_list):
        for j, attr in enumerate(list):
            nested_out[j][i] = attr
    return nested_out
    

def preprocess(record: list[str]) -> list[str]:
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
                difference = int(record[i]) - int(record[i + 1])
                preprocessed_record.append(difference)

            case "IG Setup Time":
                datetime = record[i].split(" ")
                time = [int(v) for v in datetime[2].split(":")]
                half_day = 3600 * 12 * (datetime[3] == "PM")
                time_seconds = time[0] * 3600 + time[1] * 60 + time[2] + half_day
                preprocessed_record.append(time_seconds)
                day_seq = get_day_from_date(datetime[0])
                preprocessed_record.append(day_seq)

            case "Calling Number":
                num = record[i] 
                if num != "anonymous":
                    # convert number to international format
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                    preprocessed_record.append(p_int)
                else:
                    preprocessed_record.append(0)

            case "Called Number":
                num = record[i]
                if num != "anonymous":
                    # convert number to international format
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                    preprocessed_record.append(p_int)
                    # get destination from number
                    preprocessed_record.append(get_destination(str(p_int)[1:]))
                else:
                    preprocessed_record.append(0)
                    preprocessed_record.append("N/a")
        
            case "IG Packet Received":
                difference = int(record[i + 3]) - int(record[i])
                preprocessed_record.append(difference)

            case "EG Packet Received":
                difference = int(record[i + 1]) - int(record[i])
                preprocessed_record.append(difference)

            case attribute if attribute in persist:
                preprocessed_record.append(record[i])
    return preprocessed_record

def vectorise(data_array: list[list[str]]) -> list[list[int]]:
    with open("values_dump.txt", "w") as f:
        f.write("")
    attributes_array = []
    for i, attributes in enumerate(data_array):
        values_hash = {}
        attributes_out = []
        for attr in attributes:
            if can_cast_to_int(attr):
                attributes_out.append(int(attr))
            elif values_hash.get(attr, 0):
                attributes_out.append(values_hash[attr])
            else:
                values_hash[attr] = len(values_hash)
                attributes_out.append(values_hash[attr])
        attributes_array.append(attributes_out)
        
        if values_hash:
            with open("values_dump.txt", "a") as f:
                values_to_write = "\n".join([f"{v}: {j}" for (v, j) in values_hash.items()])
                f.write(f"values for attribute at index {i}" + "\n" + values_to_write + "\n")
        
    return attributes_array

def normalise(attributes_array: list[list[int]]) -> list[list[float]]:
    # normalise each dimension to have a range of 1
    array_out = []
    for attributes in attributes_array:
        attributes_out = []
        mx, mn = max(attributes), min(attributes)
        if not mx: mx += 1
        for attr in attributes:
            rnge = mx - mn if mx - mn else mx
            attributes_out.append((attr - mn) / rnge)
        array_out.append(attributes_out)
    return array_out



        
    
    
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