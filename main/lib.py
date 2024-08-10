
# ||function library for k-means program||
import re
# import phonenumbers
import numpy as np
from typing import *
import time
import os
import subprocess
import asyncio
from multiprocessing import Pool, Lock

#  <<K-MEANS CLUSTERING>>

def reassign(wrap):
    """Reassigns record to closest centroid."""
    (record, centroids) = wrap
    (dist_1, index_1), (dist_2, _) = get_2_closest_centroids(record[:record.shape[0] - 1], centroids)
    closest_centroid_index = index_1
    if record[-1] != closest_centroid_index and abs(dist_1 - dist_2) > 1e-4:
        record[-1] = closest_centroid_index
        return record
    else: return record

# cluster data using k-means algorithm
#@profile_t_plot
def kmeans(k: int, data_array_r: np.ndarray) -> np.ndarray:
    """Runs K-means clustering algorithm on data_array.
       1) Centroids are chosen.
       2) Records are assigned to closest centroids.
       3) Centroids are recalculated.
       4) 2 and 3 repeat until <1% of records are reassigned."""

    centroids = k_means_pp(k, data_array_r)
    #centroid_list = [data_array_r[i] for i in np.random.randint(data_array_r.shape[0], size=k)]
    #centroids = np.stack(centroid_list)
    print("Initial centroids assigned.")
    z = np.array([np.zeros(data_array_r.shape[0])])
    data_array = np.concatenate((data_array_r, z.T), axis=1)
    centroids_new = centroids.copy()
    t = lambda a: np.array(a).T
    
    iter = 0
    while True:

        reassignments = 0
        # assign each data point to closest centroid
        cores = os.cpu_count()
        o_array_prev = t(data_array[:, -1])
        wrap = [(record, centroids) for record in data_array]
        with Pool(processes=cores) as p:
            data_array = p.map(reassign, wrap)
        data_array = np.array(data_array)
        o_array = t(data_array[:, -1])

        # stop algorithm when <1% of records are reassigned
        reassignments = np.sum(o_array_prev != o_array)
        if reassignments <= (data_array.shape[0] // 100): 
            return k, o_array, centroids
        print(f"\tIter {iter} ({reassignments} reassignments) with {k} clusters")
        iter += 1

        # calculate new centroid coordinates
        for i, _ in enumerate(centroids):
            owned_records = data_array[o_array == i]
            owned_records = np.delete(owned_records, -1, 1)
            if owned_records.any(): 
                centroids_new[i] = np.apply_along_axis(np.average, 0, owned_records)
        centroids = centroids_new

def k_means_pp(k: int, data: np.ndarray) -> np.ndarray:
    """K++ algorithm: randomly select initial centroids from unclustered data."""
    data = np.stack([data[i] for i in np.random.randint(data.shape[0], size=data.shape[0] // 20)])
    chosen_indexes = [np.random.randint(0, data.shape[0])]
    centroids = [data[chosen_indexes[0]]]

    while len(centroids) < k:
        square_distances = {}
        for i, record in enumerate(data):
            if i not in chosen_indexes:
                (dist_to_nearest_centroid, _) = get_2_closest_centroids(record, centroids, single = True)
                square_distances[i] = dist_to_nearest_centroid ** 2

        sum_of_squares = sum([v for v in square_distances.values()])

        for index, sq_dist in square_distances.items():
            if np.random.rand() < (sq_dist / sum_of_squares):
                centroids.append(data[index])
                chosen_indexes.append(index)
                break
    return np.array(centroids)

def distance_to_centroid(record: np.ndarray, centroid: np.ndarray) -> float:
    """Calculate Euclidean distance between record and centroid."""
    return np.sqrt(np.sum(np.power((np.subtract(record, centroid)), 2)))

def get_2_closest_centroids(record: np.ndarray, centroids: np.ndarray, single = False) -> tuple:
    """Calculates tuple of distance between record and nearest centroid, and index of nearest centroid.
       Returns tuples for closest and 2nd closest centroids."""
    distances = [(distance_to_centroid(record, centroid), i) for i, centroid in enumerate(centroids)]
    distances.sort()
    if single: return distances[0]
    return distances[0], distances[1]


def optimal_k_decision(data: np.ndarray, centroids: np.ndarray, o_array) -> float:
    """Calculate CH Index of clustered data set."""
    vectors = data.shape[0] * data.shape[1]
    clusters = centroids.shape[0]
    overall_centroid = np.apply_along_axis(np.average, 0, centroids)
    # calculate between-cluster sum of squares
    bcss, wcss = 0, 0
    for i, centroid in enumerate(centroids):
        vectors_in_centroid = data[o_array == i]
        # calculate within-cluster sum of squares
        wcss += np.sum([distance_to_centroid(vec, centroid) ** 2 for vec in vectors_in_centroid])
        # calculate between-cluster sum of squares
        bcss += vectors_in_centroid.shape[0] * (distance_to_centroid(centroid, overall_centroid) ** 2)
    # calculate Calinski–Harabasz (CH) index
    return bcss * (vectors - clusters) / (wcss * (clusters - 1))

async def group_echo_test(i, recs):
    """Passes record to assignment logic, receives and decodes result."""
    
    fraud_hash_r = ""
    assignments = []
    for record in recs:
        reader, writer = await asyncio.open_connection(
        '127.0.0.1', 8888)
        writer.write(record.encode())
        await writer.drain()

        data_r = await reader.read(100)
        data = data_r.decode()
        # print(f'Received: {data}')
        if not fraud_hash_r: fraud_hash_r = data.split("; ")[1]
        assignments.append(int(float(data.split("; ")[0])))
            
        writer.close()
        await writer.wait_closed()

    fraud_hash = dict([tuple(map(float,pair.split(": "))) for pair in fraud_hash_r[1:len(fraud_hash_r)-1].split(", ")])
    results = [0, 0, 0, 0]
    for v in assignments:
        if fraud_hash[float(v)] == 1.0:
            if v == i: results[0] += 1
            else: results[2] += 1
        else:
            if v == i: results[1] += 1
            else: results[3] += 1

    return results

def evaluate_assignment_accuracy():
    """Passes cached records from clustering to assignment pipeline,
       compares original cluster labels to assigned labels to form confusion matrix."""
    with open("main/data/dump.txt", "r") as f:
        l = f.readlines()
        ll = len(l)
    hash = {}
    for record in l:
        (i, rec) = tuple(record.split(",", 1))
        if hash.get(i): hash[i].append(rec)
        else: hash[i] = [rec]
    # tp, tn, fp, fn
    results = [0, 0, 0, 0]
    for i, recs in hash.items():
        r = asyncio.run(group_echo_test(int(i), recs))
        for j in range(4):
            results[j] += r[j]
    x = ["True positives", "True negatives", "False positives", "False negatives"]
    print(f"Total values tested: {ll}")
    for i in range(4):
        print(f"{x[i]}: {results[i]}")

#  <<DATA PREPROCESSING>>

def run_bash_script(adr, arg = None):
    subprocess.run(["chmod", "+x", adr])
    subprocess.run(["bash", adr] + [arg] if arg else [])

def get_latest_data():
    """Download most recent CDR data from S3."""
    adrs = ["main/bash_scripts/get_keys.sh", "main/bash_scripts/reload.sh"]
    run_bash_script(adrs[0])
    with open("main/data/cache.txt", "r") as f:
        l = re.findall("\n[^}{]+\n", f.read())[0]
    l = re.findall("[0-9]{14}", l)
    t = max([int(s) for s in l])
    run_bash_script(adrs[1], f"exp_odine_u_332_p_1_e_270_{t}")

def get_destination(number):
    """Get destination from MDL using number prefix."""
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
    
def can_cast_to_float(v: str) -> bool:
    try:
        _ = float(v)
    except ValueError:
        return False
    except TypeError:
        return False
    else:
        return True

def sanitise_string(string):
    """Remove format-breaking commas and N/a values from text fields."""
    comma_str = re.findall('"[^,"]+,[^,"]+"', string)
    hyphen_str = [re.sub(',', '-', s) for s in comma_str]
    for i, h in enumerate(hyphen_str):
        string = re.sub(comma_str[i], h, string)
    return string

def to_record(s):
    """Map record from comma-delineated string to python list."""
    return sanitise_string(s).split(',')[:25]

def prune_attrs(data_array, single = False):
    """Compress 2D array of strings, preserving relevant fields."""
    attrs = np.array(["Calling Number", "Called Number", "Buy Destination", "Destination", "PDD (ms)", "Duration (min)"])
    attr_indexes = [9,12,13,11,14,22]
    # print(data_array[:,22])
    # print(max(data_array[:,12]))
    t = lambda a: np.array([a]).T
    if not single:
        data_array = np.hstack(tuple([t(data_array[:,i]) for i in attr_indexes]))
    else:
        data_array = np.array([data_array[i] for i in attr_indexes]).T
    return np.vstack((attrs, data_array))

def process_number(num):
    """Preprocess phone numbers."""
    if num == "anonymous": 
        return (0) 
    # convert number to international format
    # try:
    #     # p = phonenumbers.parse("+" + num, None)
    #     # p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
    # except phonenumbers.phonenumberutil.NumberParseException:
    #     p_int = num
    p_int = re.sub("[ +-]", "", num)
    cutoff = 12
    z_l = cutoff - len(p_int) if (cutoff - len(p_int)) >= 0 else 0
    return (p_int + "0" * z_l)[:cutoff]

def process_pdd(pdd):
    # cap pdd field at 240 seconds
    if can_cast_to_float(pdd):
        return pdd if float(pdd) < 2.4e5 else '240000'

def process_duration(pdd):
    # cap pdd field at 240 seconds
    if can_cast_to_float(pdd):
        return pdd if float(pdd) < 1000 else '1000'

def preprocess_n(attrs):
    """Preprocess each field according to its label."""
    col = attrs[0]
    attrs = np.delete(attrs, 0)
    if (col == "Calling Number" or col == "Called Number"):
        return np.array(list(map(process_number, attrs)))
    elif (col == "PDD (ms)"):
        return np.array(list(map(process_pdd, attrs)))
    else:
        return attrs
    
def vectorise(wrap: np.ndarray, single = False) -> np.ndarray:
    """https://i.kym-cdn.com/entries/icons/facebook/000/023/977/cover3.jpg"""

    attr_name = wrap[0]
    attributes = np.delete(wrap, 0)

    values_hash = {}
    esc = "------------" # escape string - should never appear in dataset
    max = 0
    vals = [12, 12, 5, 5, 6, 3]
    attr_names = ["Calling Number", "Called Number", "Buy Destination", "Destination", "PDD (ms)", "Duration (min)"]
    cutoff = dict([(attr_names[i], v) for i, v in enumerate(vals)])

    attributes_out = np.empty(attributes.shape[0])
    for i, attr in enumerate(attributes):
        if can_cast_to_float(attr):
            attributes_out[i] = float(attr) if len(attr.split(".")[0]) <= cutoff[attr_name] else 10 ** cutoff[attr_name] 
        elif values_hash.get(attr, esc) != esc:
            attributes_out[i] = float(values_hash[attr])
        else:
            #print(attr)
            #print("from conditional", values_hash)
            values_hash[attr] = len(values_hash)
            attributes_out[i] = float(values_hash[attr])
        if max < attributes_out[i] and attr_name in ["Called Number", "Calling Number", "PDD (ms)", "Duration (min)"]:
            max = attributes_out[i]
            print(max)
    #print(values_hash)
    
    with open(f"main/data/values_dump_{attr_name}.txt", "w") as f:
        if values_hash:
            for (v, k) in values_hash.items():
                f.write(f"{v}: {k}\n")
        else:
            f.write("")
        
    return attributes_out

def vectorise_single(wrap: np.ndarray) -> np.ndarray:
    """Map non-numeric fields in individual CDR to numeric representations.
       Reads data from values_hash files generated by vectorise during dataset preprocessing."""

    attr_name = wrap[0]
    attributes = wrap[1]

    with open(f"main/data/values_dump_{attr_name}.txt", "r") as f:
        if f.readline():
            values_hash = dict([tuple(l.replace("\n", "").split(": ")) for l in f.readlines()])
        else:
            values_hash = {}
        #if not single: print("from file read", values_hash)
        
    esc = "------------" # escape string - should never appear in dataset

    # print(values_hash)
    attr = attributes
    if can_cast_to_float(attr):
        out = float(attr) if np.isfinite(float(attr)) else 0.0
    elif values_hash.get(attr, esc) != esc:
        out = float(values_hash[attr])
    else:
        values_hash[attr] = len(values_hash)
        out = float(values_hash[attr])
    
    with open(f"main/data/values_dump_{attr_name}.txt", "w") as f:
        for (v, k) in values_hash.items():
            f.write(f"{v}: {k}\n")
        
    return out

def normalise(attributes: np.ndarray) -> np.ndarray:
    """Normalise dimension to have a range of 1."""
    mx, mn = np.max(attributes), np.min(attributes)
    print(mx, mn)
    if not mx: mx += 1
    rnge = mx - mn if mx - mn else mx
    norm = lambda a: (a - mn) / rnge
    return norm(attributes)

def save_minmax(data_array: np.ndarray):
    """Save max and min values of each dimension to file."""
    minmax = lambda attrs: ",".join([str(np.max(attrs)), str(np.min(attrs))])
    out = np.apply_along_axis(minmax, 0, data_array).T.tolist()
    with open("minmax.txt", "w") as f:
        f.write(";".join(out))

def normalise_single(attributes: np.ndarray) -> np.ndarray:
    """Normalise vectorised CDR relative to dataset."""
    with open("minmax.txt", "r") as f:
        mxmn = f.read().split(";")
    out = np.empty(attributes.shape[0])
    for i, attr in enumerate(attributes):
        mx, mn = tuple([float(v) for v in mxmn[i].split(",")])
        if not mx: mx += 1
        rnge = mx - mn if mx - mn else mx
        out[i] = (attr - mn) / rnge
    return out

def get_raw_data(mxg):
    """Loads data from file and maps to 2D numpy array."""
    mx = int(float(mxg) * 1024**3)
    # size = os.path.getsize("main/data/cdr.csv")
    #filestep = size // mx if size // mx >= 1 else 1

    with open("main/data/cdr.csv", "r", encoding="utf-8") as f:
            # systematic sampling of dataset
            # csv_list_r = f.readlines(size)
            # csv_list = csv_list_r[::filestep]
            # del csv_list_r
            csv_list = f.readlines(mx)
    print(f"CDR data ({len(csv_list)} records) loaded.")

    return csv_list

def get_preprocessed_data(data_array):
    """Runs function chain to produce normalised data from raw data."""
    data_array = list(map(to_record, data_array))
    data_array = np.array(data_array, dtype=object)

    data_array_pruned = prune_attrs(data_array)
    del data_array
    # data_array_preprocessed = np.apply_along_axis(preprocess_n, 0, data_array_pruned)
    t = lambda a: np.array(a).T
    lng = data_array_pruned.shape[1]
    data_array_preprocessed = np.array([preprocess_n(t(data_array_pruned[:,i])) for i in range(lng)], dtype = object).T
    del data_array_pruned
    print("Data preprocessed.")

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    names = np.array(["Calling Number", "Called Number", "Buy Destination", "Destination", "PDD (ms)", "Duration (min)"])
    wrap_arr = np.vstack((names, data_array_preprocessed))
    vector_array = np.array(np.apply_along_axis(vectorise, 0, wrap_arr), dtype=float)
    with open("test.txt", "w") as f:
        f.write("\n".join(list(map(str,vector_array[:,5]))))
    subprocess.run(["sudo", "aws", "s3api", "put-object", "--bucket", "wavecrest-terraform-ops-ew1-ai", "--key", "test.txt", "--body", "test.txt"])
    #print(vector_array[0])
    del data_array_preprocessed
    print("Data vectorised.")

    save_minmax(vector_array)
    vector_array_n = np.apply_along_axis(normalise, 0, vector_array)
    print("Data normalised.")
    return vector_array_n
    
#  <<RESULT MANAGEMENT AND INCOMING RECORD ASSIGNMENT>>

def save_clustering_parameters(centroids, data_array, o_array, alpha, beta):
    """Generates means and standard deviations of centroids.
       Saves data to file."""
    # 1: get mean and stdev for each cluster
    stdevs = np.empty([centroids.shape[0], centroids.shape[1]])
    for i, centroid in enumerate(centroids):
        c_records = data_array[o_array == i]
        for j, mean in enumerate(centroid):
            c_vals = c_records[:, j]
            stdevs[i,j] = np.sqrt(np.sum(np.power(np.array(c_vals) - mean, 2)) / (len(c_vals) - 1))

    to_str = lambda arr: "\n".join([",".join([str(v) for v in l]) for l in arr.tolist()])
    with open("main/data/clustering_parameters.txt", "w") as f:
        f.write(str(time.time()) + "\n" + ",".join([str(alpha), str(beta)]) + "\n\n" + to_str(centroids) + "\n\n" + to_str(stdevs))

def get_clustering_parameters():
    """Loads features of clusters from file."""
    to_arr = lambda l_list: np.array([[float(v) for v in l.split(",")] for l in l_list])
    with open("main/data/clustering_parameters.txt", "r") as f:
        data = f.readlines()
        a, b = tuple(data[1].split(","))
        out = data[3:]
    
    return (to_arr(out[:len(out) // 2]), to_arr(out[len(out) // 2 + 1:]), a, b)

def assign_cluster(record, centroids, stdevs, alpha = 1, beta = 1):
    """Calculates mean position of normalised record along normal
       distributions of each centroid. Appends to record index of
       centroid record is most closely aligned with."""
    normaldist = lambda mu, sd, x: np.power(sd*np.sqrt(2*np.pi),-1)*np.power(np.e,-np.power(x-mu,2)/(2*np.power(sd, 2)))
    # experimentally determined to be optimal
    s_eval = (0, 0)
    for j, means in enumerate(centroids):
        eval_list = []
        for k, mean in enumerate(means):
            eval_list.append((normaldist(mean, stdevs[j,k] * int(alpha), record[k]) * (stdevs[j,k] / np.max(stdevs[:,k]))) ** int(beta))
        c_eval = sum(eval_list) / max(eval_list)
        s_eval = (c_eval, j) if s_eval[0] < c_eval else s_eval
    (_, c_i) = s_eval
    return np.append(record, [c_i])

# naive solution
def rate_cluster_fraud(stdevs):
    """Produces map of centroid indexes to fraud ratings."""
    hash = {}
    ls = [float(np.average(c)) for c in stdevs]
    mx = max(ls)
    ls = [v / mx for v in ls]
    for i, v in enumerate(ls):
        hash[i] = v
    return hash

def preprocess_incoming_record(raw_record):
    """Takes raw CDR, runs function chain to produce normalised vector."""
    r_arr = np.array(to_record(raw_record), dtype=object)
    r_pruned = prune_attrs(r_arr, single = True)
    # r_preprocessed = np.apply_along_axis(preprocess_n, 0, r_pruned)
    # r_preprocessed = np.array([preprocess_n(v) for v in r_pruned], dtype = object)
    t = lambda a: np.array(a).T
    lng = r_pruned.shape[1]
    r_preprocessed = np.array([preprocess_n(t(r_pruned[:,i])) for i in range(lng)], dtype = object).T
    names = np.array(["Calling Number", "Called Number", "Buy Destination", "Destination", "PDD (ms)", "Duration (min)"])
    wrap_arr = np.vstack((names, r_preprocessed))
    r_vec = np.array(np.apply_along_axis(vectorise_single, 0, wrap_arr), dtype=float)
    # r_vec = np.array([vectorise(v, single = True) for v in wrap_arr])
    # r_vec = np.array([vectorise(v, single = True) for v in r_preprocessed.flatten().tolist()])
    # print(r_vec)
    r_n = normalise_single(r_vec)
    return r_n

def assign(raw_record):
    """Takes individual CDR, runs function chain to determine CDR's 
       rating of fraudulence relative to the locally stored cluster features."""
    # needs to use values_dump generated from dataset preprocessing
    preprocessed_record = preprocess_incoming_record(raw_record)
    (centroids, stdevs, alpha, beta) = get_clustering_parameters()

    # cluster indexes as keys, fraud ratings as values
    fraud_hash = rate_cluster_fraud(stdevs)
    # print(fraud_hash)
    assigned_record = assign_cluster(preprocessed_record, centroids, stdevs, alpha, beta)

    rating = fraud_hash.get(assigned_record[-1])

    # print(f"Record assigned to cluster with index {assigned_record[-1]} with fraudulence rating of {rating:.2f} / 1.0")
    return assigned_record[-1], fraud_hash