
# ||function library for k-means program||
import re
import phonenumbers
import numpy as np
from typing import *
import time
import os
import psutil
import matplotlib.pyplot as plt
import subprocess
from multiprocessing import Pool, Lock

#  <<DATA VISUALISATION>>

def plot_data(vector_array_n):
    for i, a in enumerate(vector_array_n.T):
        plt.scatter(np.array([i] * a.shape[0]), a)
    plt.savefig("main/data/savefig.png")

def plot_clustered_data(clustered_data):
    get_last = lambda v: v[-1]
    colors = ["r", "b", "g", "c", "m", "y"]
    o_array = np.apply_along_axis(get_last, 1, clustered_data)
    n = np.max(o_array) + 1
    # iterate over dimensions
    for i, attrs in enumerate(clustered_data.T):
        if i == clustered_data.shape[1] - 1: break
        # iterate over clusters
        for j in range(int(n)):
            offset = (-1 + 2 * (j / n)) * 0.15
            c_attrs = attrs[o_array == j]
            plt.scatter(np.array([i + offset] * c_attrs.shape[0]), c_attrs, color=colors[int(j) % len(colors)])

    plt.savefig("main/data/savefig.png")

def plot_clustered_data_3d(clustered_data):
    fig = plt.figure(figsize=plt.figaspect(1), layout="constrained")
    fig.suptitle(f"Frequency visualisation of {clustered_data.shape[0]} {clustered_data.shape[1] - 1}-dimensional records.")
    ax = fig.add_subplot(2, 2, 1)
    bx = fig.add_subplot(2, 2, 2)
    cx = fig.add_subplot(2, 2, 3, projection='3d')
    dx = fig.add_subplot(2, 2, 4, projection='3d')

    get_last = lambda v: v[-1]
    colors = ["r", "b", "g", "c", "m", "y"]
    o_array = np.apply_along_axis(get_last, 1, clustered_data)
    n = int(np.max(o_array) + 1)
    for i, a in enumerate(clustered_data.T):
        if i == clustered_data.shape[1] - 1: break
        for j in range(int(n)):
            offset = (-1 + 2 * (j / n)) * 0.2
            attrs = a[o_array == j]
            x = list(set(list(attrs)))
            x = np.array(x)
            hash = dict([(vx, 0) for vx in x])
            for v in attrs:
                if hash.get(v): hash[v] += 1
                else: hash[v] = 1
            f = np.array(list(hash.values()))
            f = f / np.max(f)
            ax.scatter(np.array([i + offset] * x.shape[0]), x, color=colors[int(j) % len(colors)])
            cx.scatter(x, f, zdir="y", zs = i, color=colors[int(j) % len(colors)])
            dx.scatter(x, f, zdir="y", zs = i, color=colors[int(j) % len(colors)])
            bx.scatter(np.array([i + offset] * x.shape[0]), f, color=colors[int(j) % len(colors)])
    
    cx.set_xlim(1, 0)
    cx.set_ylim(0, clustered_data.shape[1] - 2)
    cx.set_zlim(0, 1)
    cx.set_xlabel('Range')
    cx.set_ylabel('Dimension')
    cx.set_zlabel('Normalised Frequency')
    cx.view_init(elev=20., azim=-35)
    cx.set_zticks([])
    cx.set_position([0.05,0.06,0.4,0.4])

    dx.set_xlim(1, 0)
    dx.set_ylim(0, clustered_data.shape[1] - 2)
    dx.set_zlim(0, 1)
    dx.set_xlabel('Range')
    dx.set_ylabel('Dimension')
    dx.view_init(elev=20., azim=35)
    dx.set_position([0.55,0.06,0.4,0.4])
    
    ax.xaxis.tick_top()
    ax.set_xlabel('Dimension')
    ax.set_ylabel('Range')
    ax.set_position([0.12,0.5,0.35,0.35])
    bx.xaxis.tick_top()
    bx.set_xlabel('Dimension')
    bx.set_ylabel('Frequency')
    bx.set_position([0.62,0.5,0.35,0.35])


    plt.savefig("main/data/savefig.png")

def plot_single_data(preprocessed_array, vector_array_n, test_index):
    """  """
    x = list(set(list(vector_array_n[:, test_index])))
    hash = dict([(vx, 0) for vx in x])
    for v in vector_array_n[:, test_index]:
        if hash.get(v):
            hash[v] += 1
        else:
            hash[v] = 1
    y = [val for val in hash.values()]
    mode = preprocessed_array[y.index(max(y)), test_index]
    chode = preprocessed_array[x.index(max(x)), test_index]
    print(f"Most common occurence: {mode}")
    print(f"Highest appearence occurence: {chode}")
    plt.scatter(x, y)
    plt.xlabel("Range of values")
    plt.ylabel("Number of occurences")
    plt.title(f"Frequency range of values at index {test_index} across {vector_array_n.shape[0]} records.")
    plt.savefig("main/data/savefig.png")

def plot_data_3d(vector_array_n):
    fig = plt.figure(figsize=plt.figaspect(0.5))
    fig.suptitle(f"Frequency visualisation of {vector_array_n.shape[0]} {vector_array_n.shape[1]}-dimensional records.")
    ax = fig.add_subplot(1, 2, 2, projection='3d')
    bx = fig.add_subplot(1, 2, 1)

    for i, a in enumerate(vector_array_n.T):
        x = list(set(list(a)))
        hash = dict([(vx, 0) for vx in x])
        for v in a:
            if hash.get(v): hash[v] += 1
            else: hash[v] = 1
        y = np.array(list(hash.values()))
        y = y / np.max(y)
        ax.scatter(x, y, zdir="y", zs = i)

        bx.scatter(np.array([i] * a.shape[0]), a)
    
    ax.set_xlim(1, 0)
    ax.set_ylim(0, vector_array_n.shape[1])
    ax.set_zlim(0, 1)
    ax.set_xlabel('Range')
    ax.set_ylabel('Dimension')
    ax.set_zlabel('Normalised Frequency')
    ax.view_init(elev=20., azim=-35)
    
    bx.set_xlabel('Dimension')
    bx.set_ylabel('Range')

    plt.savefig("main/data/savefig.png")
    
def plot_clustering_range(graph_data, data_len):
    graph_data = sorted(graph_data, key=lambda x: x[0])
    graph_array = np.stack(graph_data, axis=0).T
    (x, y) = tuple(np.split(graph_array, 2, axis=0))
    plt.plot(x[0], y[0])
    plt.xlabel("Number of clusters")
    plt.ylabel("CH Index")
    plt.title(f"CH index evaluation of clustering for set of {data_len} records.")
    plt.savefig("main/data/savefig.png")

def plot_clustered_data_batch(clustered_data):
    colors = ["r", "b", "g", "c", "m", "y"]
    dims = ["Calling-Number", "Called-Number", "Buy-Destination", "Destination", "PDD-ms", "Duration-min"]
    filenames = []
    get_last = lambda v: v[-1]
    o_array = np.apply_along_axis(get_last, 1, clustered_data)
    n = int(np.max(o_array) + 1)
    hash = {}
    for i in range(len(dims)):
        for j in range(len(dims)):
            if i != j and not (hash.get((i, j)) or hash.get((j, i))):
                hash[(i, j)] = 1
                x, y = clustered_data[:,j], clustered_data[:,i]
                x_c, y_c = [], []
                for k in range(n):
                    x_p, y_p = x[o_array == k], y[o_array == k]
                    x_c.append(np.average(x_p))
                    y_c.append(np.average(y_p))
                    plt.scatter(x_p, y_p, color=colors[k % len(colors)])
                print(x_c, y_c)
                plt.scatter(x_c, y_c, c="k", marker="s")
                f = f"main/data/savefig_batch/{dims[i]}_{dims[j]}.png"
                plt.legend([f"cluster {l}" for l in range(n)], loc="upper right")
                plt.savefig(f)
                plt.clf()
                filenames.append(f)

    # not the cleanest solution
    with open("batch.sh", "w") as r:
        r.write("#!/usr/bin/env bash")
    with open("batch.sh", "a") as r:
        for f in filenames:
            l = f"sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key {f} --body {f}"
            r.write("\n" + l)

    subprocess.run(["chmod", "+x", "batch.sh"])
    subprocess.call("./batch.sh")
    
#  <<FUNCTION PROFILING>>
"""# NOTE: the _plot() functions below write data to a cache file. 
As well as applying the decorator to the function definition,
file I/O needs to be handled, and graphing logic needs to be implemented.
This hasn't been a priority because these functions are mainly
used for testing/benchmarking and are consequently non-critical."""

def profile_t(func):
    """Wraps function, prints execution time to terminal."""
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        t = end - start
        print(f"{func.__name__}: execution time: {t:.6f}")
        return result
    return wrapper

def profile_t_plot(func):
    """Wraps function, writes execution time to file."""
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        t = end - start
        with open("main/data/plot.txt", "a") as f:
            f.write("," + str(t)[0:6])
        return result
    return wrapper 

def profile_m_plot(func):
    """Wraps function, writes memory usage to file."""
    def wrapper(*args, **kwargs):
        start = process_memory()
        result = func(*args, **kwargs)
        end = process_memory()
        m = end - start
        with open("main/data/plot.txt", "a") as f:
            f.write("," + str(m))
        return result
    return wrapper 

def process_memory():
    """inner psutil function."""
    process = psutil.Process(os.getpid())
    mem_info = process.memory_info()
    return mem_info.rss

def profile_m(func):
    """Wraps function, prints execution time to terminal."""
    def wrapper(*args, **kwargs):

        start = process_memory()
        result = func(*args, **kwargs)
        end = process_memory()
        m = end - start
        print(f"{func.__name__}:consumed memory: {m:.6f}")
        return result
    return wrapper

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
        print("Reassigning records.")
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
        print("Recalculating centroids.")
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

def test_assignments(vector_array_n, o_array, test_p, alpha, beta):
    get_last = lambda v: v[-1]

    # chosen randomly from input records for testing
    sample_size = vector_array_n.shape[0] // (100 // test_p)
    incoming_records = np.stack([np.append(vector_array_n[i], [o_array[i]]) for i in np.random.randint(vector_array_n.shape[0], size=sample_size)])
    o_array_test = np.apply_along_axis(get_last, 1, incoming_records)
    incoming_records = np.delete(incoming_records, -1, 1)

    (centroids, stdevs, _, _) = get_clustering_parameters()
    assigned_records = np.array([assign_cluster(record, centroids, stdevs, alpha, beta) for record in incoming_records])
    o_array_assigned = np.apply_along_axis(get_last, 1, assigned_records)

    alignment = np.sum(o_array_test == o_array_assigned)
    alignment_p = alignment * 100 / incoming_records.shape[0]
    print(f"Alignment: {alignment_p:.2f}%")
    return alignment_p

def optimal_ab_decision(vector_array_n, o_array, test_p, depth):
    a = np.array([1.5, 4,5])
    b = np.array([0.5, 1.5])
    mid = lambda p: 0.5 * (p[0] + p[1])
    t = lambda a: (a // 2, a % 2)
    opt = test_assignments(vector_array_n, o_array, 2, 1, 1)
    opt_list = [[1, 1, opt]]
    print(f"Initial alignment: {opt:.4f}%")
    for i in range(depth):
        alignment = {}
        # top right, top left, bottom right, bottom left
        for j in range(4):
            (x, y) = t(j)
            alignment[-opt + test_assignments(vector_array_n, o_array, test_p, mid([mid(a), a[x]]), mid([mid(b), b[y]]))] = j
        opt = sorted([v for v in alignment.keys()])[-1]
        if opt < 0: return opt_list[i][0], opt_list[i][1], opt_list
        # print(f"Alignment increase at step {i + 1}: {opt:.4f}, direction: {alignment[opt]}")
        (x, y) = t(alignment[opt])
        opt_list.append([mid([mid(a), a[x]]), mid([mid(b), b[y]]), opt])
        a[0] = mid(a)
        b[0] = mid(b)
    return mid(a), mid(b), opt_list

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
    
def can_cast_to_int(v: str) -> bool:
    try:
        _ = int(v)
    except ValueError:
        return False
    except TypeError:
        return False
    else:
        return True

def sanitise_string(string):
    """Remove format-breaking commas from text fields."""
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
    t = lambda a: np.array([a]).T
    if not single:
        data_array = np.hstack(tuple([t(data_array[:,i]) for i in attr_indexes]))
    else:
        data_array = np.array([t(data_array[i]) for i in attr_indexes]).T
    return np.vstack((attrs, data_array))

def process_number(num):
    """Preprocess phone numbers."""
    if num == "anonymous": 
        return (0) 
    # convert number to international format
    try:
        # p = phonenumbers.parse("+" + num, None)
        # p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
        p_int = re.sub("[ +-]", "", num)
    except phonenumbers.phonenumberutil.NumberParseException:
        p_int = num
    return (p_int + "0" * (13 - len(p_int)))[:13]

def preprocess_n(attrs):
    """Preprocess each field according to its label."""
    col = attrs[0]
    attrs = np.delete(attrs, 0)
    if col == "Calling Number" or col == "Called Number":
        return np.array(list(map(process_number, attrs)))
    else:
        return attrs
    
def vectorise(attributes: np.ndarray, single = False) -> np.ndarray:
    """https://i.kym-cdn.com/entries/icons/facebook/000/023/977/cover3.jpg"""

    with open("main/data/values_dump.txt", "r") as f:
        values_hash = dict([tuple(l.split(": ")) for l in f.readlines() if l.count(": ") == 1]) or {}

    if not single:
        attributes_out = np.empty(attributes.shape[0])
        for i, attr in enumerate(attributes):
            if can_cast_to_int(attr):
                attributes_out[i] = int(attr)
            elif values_hash.get(attr, 0):
                attributes_out[i] = values_hash[attr]
            else:
                values_hash[attr] = len(values_hash)
                attributes_out[i] = values_hash[attr]
    else:
        attr = attributes
        if can_cast_to_int(attr):
            return int(attr)
        elif values_hash.get(attr, 0):
            return int(values_hash[attr])
        else:
            values_hash[attr] = len(values_hash)
            return int(values_hash[attr])
    
    if values_hash:
        with open("main/data/values_dump.txt", "w") as f:
            values_to_write = "\n".join([f"{v}: {k}" for (v, k) in values_hash.items()])
            f.write(values_to_write)
        
    return attributes_out

def normalise(attributes: np.ndarray) -> np.ndarray:
    """Normalise dimension to have a range of 1."""
    mx, mn = np.max(attributes), np.min(attributes)
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
    size = os.path.getsize("main/data/cdr.csv")
    filestep = size // mx if size // mx >= 1 else 1
    with open("main/data/cdr.csv", "r", encoding="utf-8") as f:
            # systematic sampling of dataset
            csv_list_r = f.readlines(size)
            csv_list = csv_list_r[::filestep]
            del csv_list_r
    print(f"CDR file parsed.")

    # data in csv has row length of 129
    csv_nested_list = list(map(to_record, csv_list))
    del csv_list
    data_array = np.array(csv_nested_list, dtype=object)
    return data_array

def get_preprocessed_data(mxg):
    """Loads data and runs function chain to produce normalised data."""
    data_array = get_raw_data(mxg)
    print(f"CDR data ({data_array.shape[0]} records) loaded.")

    data_array_pruned = prune_attrs(data_array)
    del data_array
    data_array_preprocessed = np.apply_along_axis(preprocess_n, 0, data_array_pruned)
    del data_array_pruned
    print("Data preprocessed.")

    # (vectorise) convert each record to array with uniform numerical type - data stored as nested array
    with open("main/data/values_dump.txt", "w") as f:
        f.write("")
    vector_array = np.apply_along_axis(vectorise, 0, data_array_preprocessed)
    del data_array_preprocessed
    print("Data vectorised.")  

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
    r_arr = to_record(raw_record)
    r_pruned = prune_attrs(r_arr, single = True)
    r_preprocessed = np.array([preprocess_n(r_pruned[:,i]) for i in range(r_pruned.shape[1])]).T[0]
    r_vec = np.array([vectorise(v, True) for v in r_preprocessed])
    return normalise_single(r_vec)

def assign(raw_record):
    """Takes individual CDR, runs function chain to determine CDR's 
       rating of fraudulence relative to the locally stored cluster features."""
    # needs to use values_dump generated from dataset preprocessing
    preprocessed_record = preprocess_incoming_record(raw_record)
    (centroids, stdevs, alpha, beta) = get_clustering_parameters()

    # cluster indexes as keys, fraud ratings as values
    fraud_hash = rate_cluster_fraud(stdevs)
    print(fraud_hash)
    assigned_record = assign_cluster(preprocessed_record, centroids, stdevs, alpha, beta)

    rating = fraud_hash.get(assigned_record[-1])

    print(f"Record assigned to cluster with index {assigned_record[-1]} with fraudulence rating of {rating:.2f} / 1.0")
    if int(rating) == 1:
        return "Fraudulent"
    else:
        return f"Non Fraudulent ({rating:.2f}/1.0)"