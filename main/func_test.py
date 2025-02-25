from lib import *
import matplotlib.pyplot as plt
import random
import subprocess
import asyncio
import sys

marker = ["ro", "bo", "go", "co", "mo", "yo", "ko","r^", "b^", "g^", "c^", "m^", "y^", "k^"]
        
def get_pseudorandom_coords(n, x0, xm, y0, ym, k, v):
    '''Generate 2D coordinates in a '''
    out = []
    for _ in range(k):
        c = (random.random() * (xm - x0) + x0, random.random() * (ym - y0) + y0)
        for _ in range(n // k):
            (c_x, c_y) = c
            c_x = random.gauss(c_x, v)
            c_y = random.gauss(c_y, v)
            out.append(np.array([c_x, c_y]))
    return np.array(out)

# || TEST K-MEANS CLUSTERING, K-MEANS++ AND OPTIMAL K DECISION ||
def test_clustering():
    data = get_pseudorandom_coords(1000, 0, 1, 0, 1, 5, 0.2)
    k_range = [k for k in range(3, 15)]
    k_optimal = np.array([np.zeros(2) for _ in k_range])
    for i, k in enumerate(k_range):
        print(f"k: {k}")
        wrap = (k, data)
        k, o_array, centroids = kmeans(wrap)
        chi = optimal_k_decision(data, centroids, o_array)
        k_optimal[i][0] = k
        k_optimal[i][1] = chi

def test_clustering_graphing():
    data = get_pseudorandom_coords(50, 0, 1, 0, 1, 5, 0.2)
    k_range = [k for k in range(5, 10)]
    opt = [[], 0, 2]
    for k in k_range:
        wrap = (k, data)
        k, out, centroids = kmeans(wrap)
        chi = optimal_k_decision(out, centroids)
        if chi > opt[1]:
            opt = [out, chi, k]
    print(opt[2])
    plot_clustered_data_3d(opt[0])

def plot_profile():
    with open("main/data/plot.txt", "w") as f:
        f.write("")
    data = get_pseudorandom_coords(10000, 0, 20, 0, 20, 50, 0.2)
    x = [k for k in range(30, 60, 1)]
    for i, k in enumerate(x):
        wrap = (k, data)
        _, _, _ = kmeans(wrap)
        print(x[i])

    with open("main/data/plot.txt", "r") as f:
        y = f.read().split(",")[1:]
    y = [float(v) for v in y]

    plt.plot(x, y, "r-")
    plt.xlabel("Number of clusters")
    plt.ylabel("Execution time (s)")
    plt.title(f"Execution time evalutation for kmeans() for {len(data)} pseudorandom records.")
    plt.savefig("main/data/savefig.png")

def cluster_size_dist():
    load_sizes = [0.2, 0.75]
    with open("main/data/clustering_stats.txt.txt", "w") as f:
        pass
    for s in load_sizes:
        for _ in range(1):
            subprocess.run(["chmod", "+x", "run.sh"])
            subprocess.run(["./run.sh", f"{s}", "2", "9", "1"])
    with open("main/data/clustering_stats.txt.txt", "r") as f:
        lines = f.readlines()
        [print(l) for l in lines]

def plot_cluster_dist():
    colors = ["r", "b", "g", "c", "m", "y"]
    hash = {}
    artists = []
    fig, ax = plt.subplots()
    with open("main/main/data/clustering_stats.txt.txt", "r") as f:
        lines = f.readlines()
    for l in lines:
        s = l.split(": ")[0]
        v_r = hash.get(s)
        if not v_r:
            hash[s] = len(hash) + 1
            v = len(hash)
        else:
            v = v_r
        y = np.array(sorted([float(n) for n in l.split(": ")[1].split(",")]))
        y = y / float(s)
        x = np.arange(y.shape[0])
        print(y)
        if v_r:
            ax.plot(x, y, c=colors[v - 1])
        else:
            line, = ax.plot(x, y, c=colors[v - 1], label=f"{s}")
            artists.append(line)
    ax.legend(handles=artists, title="Dataset size")
    ax.set_xlabel('Clusters (ordered by size, ascending)')
    ax.set_ylabel('Cluster size (as fraction of total dataset size)')
    plt.show()

def test_optimal_ab():
    vector_array_n = get_preprocessed_data(get_raw_data(sys.argv[1]))
    # vector_array_n = get_pseudorandom_coords(5000, 0, 1, 0, 1, 3, 0.2)
    _, o_array, cs = kmeans((4, vector_array_n))
    save_clustering_parameters(cs, vector_array_n, o_array, 1, 1)

    test_p = int(sys.argv[2])
    depth = int(sys.argv[3])
    a, b, opt_list = optimal_ab_decision(vector_array_n, o_array, test_p, depth)
    acc = test_assignments(vector_array_n, o_array, test_p, a, b)
    print(f"Accuracy at test proportion of {test_p:.4f}%, depth of {depth}: {acc}")
    
    ax = plt.figure().add_subplot(projection='3d')
    opt_list = np.array(opt_list)
    ax.plot(opt_list[:, 0], opt_list[:, 1], opt_list[:,2])
    ax.set_xlim(1.5, 4.5)
    ax.set_ylim(0.5, 1.5)
    ax.set_zlim(0, 100)
    ax.set_xlabel('Alpha')
    ax.set_ylabel('Beta')
    ax.set_zlabel('Accuracy (%)')
    plt.title("Optimization for accuracy as a function of (alpha, beta)")
    plt.savefig("savefig.png")
    subprocess.run(["sudo", "aws", "s3api", "put-object", "--bucket", "wavecrest-terraform-ops-ew1-ai", "--key", "savefig.png", "--body", "savefig.png"])

def graph_ab_over_size():
    sizes = [float(v) for v in sys.argv[1].split(",")]
    data = {}
    x = np.arange(len(sizes))
    width = 0.15
    multiplier = 0

    for i in sizes:
        vector_array_n = get_preprocessed_data(get_raw_data(i))
        # vector_array_n = get_pseudorandom_coords(5000, 0, 1, 0, 1, 3, 0.2)
        _, o_array, cs = kmeans((4, vector_array_n))
        save_clustering_parameters(cs, vector_array_n, o_array, 1, 1)
        # for j in [int(v) for v in sys.argv[2].split(",")]:
        #     test_p = 5
        #     depth = j
        #     if j == 0: a, b = 1, 1
        #     else: a, b, _ = optimal_ab_decision(vector_array_n, o_array, test_p, depth)
        #     acc = round(test_assignments(vector_array_n, o_array, test_p, a, b), 2)
        #     print(f"Optimal alignment: {acc:.4f}%")
        #     if data.get(j):
        #         data[j].append(acc)
        #     else:
        #         data[j] = [acc]
        test_p = 5
        data["No optimization"] = [round(test_assignments(vector_array_n, o_array, test_p, 1, 1), 2)]
        a, b, _ = optimal_ab_decision(vector_array_n, o_array, test_p, 1)
        data["Dynamic opt., depth=1"] = [round(test_assignments(vector_array_n, o_array, test_p, a, b), 2)]
        a, b, _ = optimal_ab_decision(vector_array_n, o_array, test_p, 2)
        data["Dynamic opt., depth=2"] = [round(test_assignments(vector_array_n, o_array, test_p, a, b), 2)]
        data["midrange alpha,beta"] = [round(test_assignments(vector_array_n, o_array, test_p, 3, 1), 2)]

    fig, ax = plt.subplots()
    for l, acc in data.items():
        offset = width * multiplier
        # l = f"{d} iterations" if d != 0 else "No optimization"
        rects = ax.bar(x + offset, acc, width, label=l)
        # ax.bar_label(rects, padding=3)
        multiplier += 1
    
    ax.set_ylabel("Accuracy (%)")
    ax.set_xlabel("Dataset size (GB)")
    ax.set_title("Effect of parameter optimization on accuracy")
    ax.set_xticks(x + width, sizes)
    ax.legend(loc='lower right')
    ax.set_ylim(0, 100)
    plt.savefig("savefig.png")
    subprocess.run(["sudo", "aws", "s3api", "put-object", "--bucket", "wavecrest-terraform-ops-ew1-ai", "--key", "savefig.png", "--body", "savefig.png"])


def graph_test_assignments():
    
    fig, ax = plt.subplots()
    color = ["r", "g", "b"]
    test_p = 5

    vector_array_n = get_preprocessed_data(get_raw_data(sys.argv[1]))
    _, o_array, _ = kmeans((4, vector_array_n))

    x = [v * 0.01 for v in range(95, 104)] * 2
    y = [test_assignments(vector_array_n, o_array, test_p, alpha=1, beta=j) for j in x]
    ax.scatter(x, y)
    ax.set_xlabel("Value of exp. factor applied to n.d. magnitude")
    ax.set_ylabel(f"Assignment accuracy % (relative to clustering, {test_p}% of input data)")

    plt.title(f"Accuracy over exp. factor range, {sys.argv[1]}GB records, 4 clusters")
    plt.legend(["beta range", "alpha range"])
    
    plt.savefig("savefig.png")
    subprocess.run(["sudo", "aws", "s3api", "put-object", "--bucket", "wavecrest-terraform-ops-ew1-ai", "--key", "savefig.png", "--body", "savefig.png"])

async def tcp_echo_client(message):
    reader, writer = await asyncio.open_connection(
        '127.0.0.1', 8888)

    #print(f'Send: {message}')
    writer.write(message.encode())
    await writer.drain()

    data = await reader.read(100)
    print(f'Received: {data.decode()}')

    #print('Close the connection')
    writer.close()
    await writer.wait_closed()
    
def test_single_group_preprocessing():
    s = float(sys.argv[2]) # size in GB
    d_arr = get_raw_data(s)
    group_p = get_preprocessed_data(d_arr)
    rnge = np.random.randint(len(d_arr), size=100)
    eq = 0
    for i, record in enumerate(d_arr):
        if i in rnge:
            single_p = preprocess_incoming_record(record)
            if np.all([single_p == group_p[i]]):
                eq += 1
    print(f"Single and group preprocessing equivalent for {eq}/{100} tested records. Tested with group of {len(d_arr)} records.")

if __name__ == "__main__":
    if sys.argv[1] == "ensemble":
        with open("main/data/dump.txt", "r") as f:
            l = f.readlines()[::int(sys.argv[2])]
        i_p = -1
        for record in l:
            (i, rec) = tuple(record.split(",", 1))
            if i_p != i:
                print(f"testing for record assigned to cluster {i}:")
                i_p = i
            asyncio.run(tcp_echo_client(rec))
    elif sys.argv[1] == "preprocessing":
        test_single_group_preprocessing()