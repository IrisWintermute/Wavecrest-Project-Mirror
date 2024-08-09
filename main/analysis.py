import numpy as np
import os
import psutil
import matplotlib.pyplot as plt

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