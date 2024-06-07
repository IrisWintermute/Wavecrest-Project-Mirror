
# ||function library for k-means program||
import random
import re
import phonenumbers

# cluster data using k-means algorithm
def kmeans(k: int, data_array: list[list[float]]) -> list[list[float]]:
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

        sum_of_squares = sum(square_distances.values())

        for index, dist in square_distances.items():
            if random.random() < (dist / sum_of_squares):
                centroids.append(data[index])
                break

    return centroids

# calculate distance between record and centroid
def distance_to_centroid(record: list[float], centroid: list[float]) -> float:
    return sum([abs(centroid[i] - attribute) ** 2 for i, attribute in enumerate(record)]) ** 0.5

# returns tuple of distance between record and nearest centroid, and index of nearest centroid
def get_closest_centroid(record: list[float], centroids: list[list[float]]) -> tuple[float, int]:
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    return distances.sort(key = lambda d, _: d)[0]

# reduce list of input vectors into a single vector representing the average of input vectors
def average(records: list[list[float]]) -> list[float]:
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
    with open("./data/mdl.csv", "r") as f:
        lines = f.readlines()
        match = ("", "")
        for line in lines:
            line_list = line.split(",")
            # check if prefix matches start of number
            # obtain the longest matching prefix - most precise destination
            if re.search(f"^{line_list[4]}", number) and match[0] < line_list[4]:
                match = (line_list[4], line_list[1])
        (dest, _) = match
        return dest

def get_day_from_date(date):
    # takes date and returns int in range 0-7, corresponding to monday-sunday
    (month, day, year) = tuple([int(val) for val in date.split("/")])
    year_code = (year + (year // 4)) % 7
    month_map = "033614625035"
    month_code = int(month_map[month])
    century_code = 6 # valid for dates in the 21st century
    year += 2000
    # check if year is leap year
    leap_year_code = 0
    if ((year // 4 == 0 and year // 100 != 0) or (year // 400 == 0)) and (month in [1, 2]):
        leap_year_code = 1
    return (year_code + month_code + century_code + day - leap_year_code - 1) % 7
    
    
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
                datetime = record[i].split(" ")
                time = datetime[2].split(":")
                half_day = 3600 * 12 * (datetime[4] == "PM")
                time_seconds = time[0] * 3600 + time[1] * 60 + time[2] + half_day
                preprocessed_record.append(time_seconds)
                day_seq = get_day_from_date(datetime[1])
                preprocessed_record.append(day_seq)

            case "Calling Number":
                num = record[i]
                # convert number to international format
                p = phonenumbers.parse(num, None)
                p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                preprocessed_record.append(p_int)

            case "Called Number":
                num = record[i]
                # convert number to international format
                p = phonenumbers.parse(num, None)
                p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                preprocessed_record.append(p_int)
                # get destination from number
                preprocessed_record.append(get_destination(num))
        
            case "IG Packet Recieved":
                difference = record[i + 3] - record[i]
                preprocessed_record.append(difference)

            case "EG Packet Recieved":
                difference = record[i + 1] - record[i]
                preprocessed_record.append(difference)

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

def normalise(vector: list[int]) -> list[float]:
    # normalise vector to have a length of 1
    length = sum([val * 2 for val in vector]) ** 0.5
    for attribute in vector:
        attribute /= length
    return vector
    
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