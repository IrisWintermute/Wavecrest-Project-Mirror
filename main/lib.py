
# ||function library for k-means program||
import random
import re
import phonenumbers
import numpy as np
from func_test import profile_m, profile_t, profile_t_plot, profile_m_plot
from typing import *

# cluster data using k-means algorithm
# @profile_t_plot
def kmeans(k: int, data_array_r: list) -> list:
    # use kmeans++ to get initial centroid coordinates
    # centroids = k_means_pp(k, data_array_r)
    centroids = np.array([np.array(data_array_r[np.random.randint(0, len(data_array_r))]) for _ in range(k)])
    print("Initial centroids assigned.")
    data_array = np.array([np.array(vec + [0]) for vec in data_array_r])
    centroids_new = centroids

    iter = 0
    while True:

        reassignments = 0
        ownership_count = [record[-1] for record in data_array]
        ownership_count.sort()
        # assign each data point to closest centroid
        for record in data_array:
            (_, closest_centroid_index) = get_closest_centroid(record[:record.shape[0] - 1], centroids)
            if record[-1] != closest_centroid_index and ownership_count.count(record[-1]) > 1: 
                ownership_count.remove(record[-1])
                record[-1] = closest_centroid_index
                reassignments += 1

        # stop algorithm when <1% of records are reassigned
        if reassignments < data_array.shape[0] // 100: return data_array, centroids
        print(f"    Iter {iter} ({reassignments} reassignments)")
        iter += 1

        # calculate new centroid coordinates
        for i, _ in enumerate(centroids):
            fltr = np.array([i])
            owned_records = data_array[np.in1d(data_array[:, -1], fltr)]
            owned_records = np.array([record[0:record.shape[0] - 1] for record in owned_records])
            if owned_records.any(): 
                centroids_new[i] = average(owned_records)

        centroids = centroids_new

# get data from S3 bucket
# when user_data script is run upon EC2 deployment, all data in s3 bucket is synced to ./data repository
# data copied will include CDR and MDL data

# K++ algorithm
# randomly select initial centroids from unclustered data
def k_means_pp(k: int, data_r: list) -> list:
    data = np.array([np.array(vec) for vec in data_r])
    chosen_indexes = [np.random.randint(0, data.shape[0])]
    centroids = [data[chosen_indexes[0]]]

    while len(centroids) < k:
        square_distances = {}
        for i, record in enumerate(data):
            if i not in chosen_indexes:
                (dist_to_nearest_centroid, _) = get_closest_centroid(record, centroids)
                square_distances[i] = dist_to_nearest_centroid ** 2

        sum_of_squares = sum([v for v in square_distances.values()])

        for index, sq_dist in square_distances.items():
            if np.random.rand() < (sq_dist / sum_of_squares):
                centroids.append(data[index])
                chosen_indexes.append(index)
                break
    return np.array(centroids)

def distance_to_centroid(record: list, centroid: list) -> float:
    # calculate distance between record and centroid
    return np.sqrt(np.sum(np.power((record - centroid), 2)))

def get_closest_centroid(record: list, centroids: list) -> tuple:
    # returns tuple of distance between record and nearest centroid, and index of nearest centroid
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    distances.sort()
    return distances[0]

def average(records: list) -> list:
    # reduce list of input vectors into a single vector representing the average of input vectors
    attributes = diagonal_mirror(records)
    avg = np.array([np.sum(vals) / vals.shape[0] for vals in attributes])
    return avg

    


# return optimal k and clustered data from kmeans(k, data)
def optimal_k_decision(clustered_data: list, centroids: list) -> float:
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
        wcss += np.sum([distance_to_centroid(vec[:vec.shape[0] - 1], centroid) ** 2 for vec in vectors_in_centroid])
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
    (year, month, day) = tuple([int(val) for val in date.split("-")])
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
    
def diagonal_mirror(nested_list: list) -> list:
    outer = nested_list.shape[0]
    inner = nested_list[0].shape[0]
    nested_out = np.array([np.zeros(outer) for _ in range(inner)])
    for i, list in enumerate(nested_list):
        for j, attr in enumerate(list):
            nested_out[j][i] = attr
    return nested_out

def diagonal_mirror_mv(nested_list: list) -> list:
    outer = len(nested_list)
    inner = len(nested_list[0])
    nested_out = [[0] * outer for _ in range(inner)]
    for i, list in enumerate(nested_list):
        for j, attr in enumerate(list):
            nested_out[j][i] = attr
    return nested_out
    

def preprocess(record: list) -> list:
    # truncate and expand record attributes
    with open('main/data/attributes.txt') as a, open('main/data/persistent_attributes.txt') as b:
        attributes, persist = a.read().split(','), b.read().split(',')
    preprocessed_record = []

    # parse exception, attribute may have commas, horrible
    if len(record) >= 130:
        for i, attr in enumerate(record):
            if attr.count('"') == 1 and record[i + 1][0] == " ":
                record = record[:i] + [record[i] + record[i + 1]] + record[i + 2:]

    for i, attribute in enumerate(attributes):
        # enrich, truncate and translate CDR data
            
        #elif attribute == "Cust. EP IP" or attribute == "Prov. EP IP":
            #ip_data = extract_ip_data(record[i])
            #preprocessed_record.extend(ip_data)

        if attribute == "IG Duration (min)":
            try:
                difference = float(record[i]) - float(record[i + 31])
                preprocessed_record.append(difference)
            except ValueError:
                print(record)

        elif attribute == "IG Setup Time":
            datetime = record[i].split(" ")
            time = [int(v) for v in datetime[1].split(":")]
            time_seconds = time[0] * 3600 + time[1] * 60 + time[2]
            preprocessed_record.append(time_seconds)
            day_seq = get_day_from_date(datetime[0])
            preprocessed_record.append(day_seq)

        elif attribute == "Calling Number":
            num = record[i] 
            if num != "anonymous":
                # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record.append(p_int)
            else:
                preprocessed_record.append(0)

        elif attribute == "Called Number":
            num = record[i]
            if num != "anonymous":
                # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record.append(p_int)
                # get destination from number
                # preprocessed_record.append(get_destination(str(p_int)[1:]))
                # called number destination contained in new CDR
                preprocessed_record.append(record[i + 1])
            else:
                preprocessed_record.append(0)
                preprocessed_record.append("N/a")
    
        elif attribute == "IG Packet Received":
            difference = float(record[i - 40]) - float(record[i])
            preprocessed_record.append(difference)

        elif attribute == "EG Packet Received":
            difference = float(record[i + 42]) - float(record[i])
            preprocessed_record.append(difference)

        elif attribute in persist:
            preprocessed_record.append(record[i])
    return preprocessed_record

def vectorise(data_array: list) -> list:
    with open("main/data/values_dump.txt", "w") as f:
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
            with open("main/data/values_dump.txt", "a") as f:
                values_to_write = "\n".join([f"{v}: {j}" for (v, j) in values_hash.items()])
                f.write(f"values for attribute at index {i}" + "\n" + values_to_write + "\n")
        
    return attributes_array

def normalise(attributes_array: list) -> list:
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