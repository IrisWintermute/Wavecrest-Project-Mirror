
# ||function library for k-means program||
import re
import phonenumbers
import numpy as np
from typing import *
import time
import os
import psutil

# cluster data using k-means algorithm
# @profile_t_plot
def kmeans(wrap: tuple) -> np.ndarray:
    (k, data_array_r) = wrap
    # use kmeans++ to get initial centroid coordinates
    # centroids = k_means_pp(k, data_array_r)
    # centroids = np.array([np.array(data_array_r[np.random.randint(0, len(data_array_r))]) for _ in range(k)])
    centroid_list = [data_array_r[i] for i in np.random.randint(len(data_array_r), size=k)]
    centroids = np.stack(centroid_list)

    print("Initial centroids assigned.")
    z = np.array([np.zeros(data_array_r.shape[0])])
    data_array = np.concatenate((data_array_r, z.T), axis=1)
    centroids_new = centroids.copy()

    iter = 0
    while True:

        reassignments = 0
        get_last = lambda v: v[-1]
        o_count = np.apply_along_axis(get_last, 1, data_array).T
        #print(o_count)
        o_hash = {}
        for c_r in np.nditer(o_count):
            c = int(c_r)
            if o_hash.get(c): o_hash[c] += 1
            else: o_hash[c] = 1
        # assign each data point to closest centroid
        for i, record in enumerate(data_array):
            (dist_1, index_1), (dist_2, _) = get_2_closest_centroids(record[:record.shape[0] - 1], centroids)
            closest_centroid_index = index_1
            if record[-1] != closest_centroid_index and o_hash[record[-1]] > 1 and abs(dist_1 - dist_2) > 1e-4: 
                o_hash[record[-1]] -= 1
                data_array[i,-1] = closest_centroid_index
                reassignments += 1
        #print(np.apply_along_axis(get_last, 1, data_array).T)

        # stop algorithm when <1% of records are reassigned
        if reassignments <= (data_array.shape[0] // 100): return k, data_array, centroids
        print(f"    Iter {iter} ({reassignments} reassignments) with {k} clusters")
        iter += 1

        # calculate new centroid coordinates
        for i, _ in enumerate(centroids):
            fltr = np.array([i])
            owned_records = data_array[np.in1d(data_array[:, -1], fltr)]
            owned_records = np.delete(owned_records, -1, 1)
            if owned_records.any(): 
                centroids_new[i] = np.apply_along_axis(np.average, 0, owned_records)

        centroids = centroids_new

# get data from S3 bucket
# when user_data script is run upon EC2 deployment, all data in s3 bucket is synced to data repository
# data copied will include CDR and MDL data

# K++ algorithm
# randomly select initial centroids from unclustered data
def k_means_pp(k: int, data_r: np.ndarray) -> np.ndarray:
    data = np.array([np.array(vec) for vec in data_r])
    chosen_indexes = [np.random.randint(0, data.shape[0])]
    centroids = [data[chosen_indexes[0]]]

    while len(centroids) < k:
        square_distances = {}
        for i, record in enumerate(data):
            if i not in chosen_indexes:
                (dist_to_nearest_centroid, _), _ = get_2_closest_centroids(record, centroids)
                square_distances[i] = dist_to_nearest_centroid ** 2

        sum_of_squares = sum([v for v in square_distances.values()])

        for index, sq_dist in square_distances.items():
            if np.random.rand() < (sq_dist / sum_of_squares):
                centroids.append(data[index])
                chosen_indexes.append(index)
                break
    return np.array(centroids)

def distance_to_centroid(record: np.ndarray, centroid: np.ndarray) -> float:
    # calculate distance between record and centroid
    return np.sqrt(np.sum(np.power((np.subtract(record, centroid)), 2)))

def get_2_closest_centroids(record: np.ndarray, centroids: np.ndarray) -> tuple:
    # returns tuple of distance between record and nearest centroid, and index of nearest centroid
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    distances.sort()
    return distances[0], distances[1]

""" def average(records: np.ndarray) -> np.ndarray:
    # reduce list of input vectors into a single vector representing the average of input vectors
    attributes = diagonal_mirror(records)
    avg = np.array([np.sum(vals) / vals.shape[0] for vals in attributes])
    return avg """

    


# return optimal k and clustered data from kmeans(k, data)
def optimal_k_decision(clustered_data: np.ndarray, centroids: np.ndarray) -> float:
    vectors = clustered_data.shape[0] * clustered_data[0].shape[0]
    clusters = centroids.shape[0]
    overall_centroid = np.apply_along_axis(np.average, 0, centroids)
    print(overall_centroid)
    # calculate between-cluster sum of squares
    bcss, wcss = 0, 0
    for i, centroid in enumerate(centroids):
        fltr = np.array([i])
        vectors_in_centroid = clustered_data[np.in1d(clustered_data[:, -1], fltr)]
        # calculate within-cluster sum of squares
        wcss += np.sum([distance_to_centroid(vec[:vec.shape[0] - 1], centroid) ** 2 for vec in vectors_in_centroid])
        # calculate between-cluster sum of squares
        bcss += vectors_in_centroid.shape[0] * (distance_to_centroid(centroid, overall_centroid) ** 2)
    # calculate Calinski–Harabasz (CH) index
    return bcss * (vectors - clusters) / (wcss * (clusters - 1))
    
def get_destination(number):
    with open("main/data/MDL_160524.csv", "r") as f:
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
    
def diagonal_mirror(nested_list: np.ndarray) -> np.ndarray:
    """ outer = nested_list.shape[0]
    inner = nested_list[0].shape[0]
    nested_out = np.array([np.empty(outer, dtype=datatype) for _ in range(inner)])
    for i, list in enumerate(nested_list):
        for j, attr in enumerate(list):
            nested_out[j][i] = attr
    return nested_out """
    return np.rot90(np.fliplr(nested_list))

# regex hacking to capture double-quoted 
def sanitise_string(string):
    comma_str = re.findall('"[^,"]+,[^,"]+"', string)
    hyphen_str = [re.sub(',', '-', s) for s in comma_str]
    for i, h in enumerate(hyphen_str):
        string = re.sub(comma_str[i], h, string)
    return string



def preprocess(record: np.ndarray) -> np.ndarray:
    # truncate and expand record attributes
    with open('main/data/attributes.txt') as a, open('main/data/persistent_attributes.txt') as b:
        attributes, persist = a.read().split(','), b.read().split(',')
    preprocessed_record = np.empty(28, dtype=str)

    # parse exception, attribute may have commas, horrible
    # if len(record) >= 130:
    #     for i, attr in enumerate(record):
    #         if i < len(record) - 2 and attr and record[i + 1] and attr[0] == '"' and record[i + 1][0] == " ":
    #             record = record[:i] + [record[i] + record[i + 1]] + record[i + 2:]

    for i, attribute in enumerate(attributes):
        # enrich, truncate and translate CDR data
            
        #elif attribute == "Cust. EP IP" or attribute == "Prov. EP IP":
            #ip_data = extract_ip_data(record[i])
            #preprocessed_record.extend(ip_data)

        if attribute == "IG Duration (min)":
            try:
                difference = float(record[i]) - float(record[i + 31])
                preprocessed_record[0] = difference
            except ValueError:
                print(record)

        elif attribute == "IG Setup Time":
            datetime = record[i].split(" ")
            time = [int(v) for v in datetime[1].split(":")]
            time_seconds = time[0] * 3600 + time[1] * 60 + time[2]
            preprocessed_record[1] = time_seconds
            day_seq = get_day_from_date(datetime[0])
            preprocessed_record[2] = day_seq

        elif attribute == "Calling Number":
            num = record[i] 
            if num != "anonymous":
                # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record[3] = (p_int)
            else:
                preprocessed_record[3] = (0)

        elif attribute == "Called Number":
            num = record[i]
            if num != "anonymous":
                # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record[4] = (p_int)
                # get destination from number
                # preprocessed_record[0] = (get_destination(str(p_int)[1:]))
                # called number destination contained in new CDR
                preprocessed_record[5] = (record[i + 1])
            else:
                preprocessed_record[4] = (0)
                preprocessed_record[5] = ("N/a")
    
        elif attribute == "IG Packet Received":
            try:
                difference = float(record[i - 40]) - float(record[i])
                preprocessed_record[6] = (difference)
            except ValueError:
                print(record)

        elif attribute == "EG Packet Received":
            try:
                difference = float(record[i + 42]) - float(record[i])
                preprocessed_record[7] = (difference)
            except ValueError:
                print(record)

        elif attribute in persist:
            j = persist.index(attribute)
            preprocessed_record[j + 8] = record[i]
    return preprocessed_record

def vectorise(attributes: np.ndarray) -> np.ndarray:
    """https://i.kym-cdn.com/entries/icons/facebook/000/023/977/cover3.jpg"""
    values_hash = {}
    attributes_out = np.empty(attributes.shape[0])
    for i, attr in enumerate(attributes):
        if can_cast_to_int(attr):
            attributes_out[i] = int(attr)
        elif values_hash.get(attr, 0):
            attributes_out[i] = values_hash[attr]
        else:
            values_hash[attr] = len(values_hash)
            attributes_out[i] = values_hash[attr]
    
    if values_hash:
        with open("main/data/values_dump.txt", "a") as f:
            values_to_write = "\n".join([f"{v}: {k}" for (v, k) in values_hash.items()])
            f.write("\n" + values_to_write + "\n")
        
    return attributes_out

def normalise(attributes: np.ndarray) -> np.ndarray:
    # normalise dimension to have a range of 1
    mx, mn = np.max(attributes), np.min(attributes)
    if not mx: mx += 1
    rnge = mx - mn if mx - mn else mx
    norm = lambda a: (a - mn) / rnge
    return norm(attributes)


def profile_t(func):
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        t = end - start
        print(f"{func.__name__}: execution time: {t}")
        return result
    return wrapper

def profile_t_plot(func):
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        t = end - start
        with open("./data/plot.txt", "a") as f:
            f.write("," + str(t)[0:6])
        return result
    return wrapper 

def profile_m_plot(func):
    def wrapper(*args, **kwargs):
        start = process_memory()
        result = func(*args, **kwargs)
        end = process_memory()
        m = end - start
        with open("./data/plot.txt", "a") as f:
            f.write("," + str(m))
        return result
    return wrapper 

# inner psutil function
def process_memory():
    process = psutil.Process(os.getpid())
    mem_info = process.memory_info()
    return mem_info.rss

def profile_m(func):
    def wrapper(*args, **kwargs):

        start = process_memory()
        result = func(*args, **kwargs)
        end = process_memory()
        m = end - start
        print(f"{func.__name__}:consumed memory: {m}")
        return result
    return wrapper
    
    
""" 
def extract_ip_data(ip_address: str) -> dict[str]:
    someone got angy at league
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