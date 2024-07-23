from lib import *
import matplotlib.pyplot as plt
import random
import subprocess
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
    data = get_pseudorandom_coords(5000, 0, 1, 0, 1, 5, 0.2)
    k_range = [k for k in range(3, 30)]
    k_optimal = np.array([np.zeros(2) for _ in k_range])
    for i, k in enumerate(k_range):
        print(f"k: {k}")
        wrap = (k, data)
        k, out, centroids = kmeans(wrap)
        #print("Clustered data and centroids: ")
        #print(centroids)
        chi = optimal_k_decision(out, centroids)
        k_optimal[i][0] = k
        k_optimal[i][1] = chi
    #print(k_optimal)
    optimal_plot = diagonal_mirror(k_optimal)
    plt.plot(optimal_plot[0], optimal_plot[1], "b-")
    plt.show()
    
    # for i in range(20):
    #     p = [val for val in out if val[-1] == i]
    #     plot = diagonal_mirror(p)
    #     plt.plot(plot[0], plot[1], marker[i % len(marker)])
    # cen_plt = diagonal_mirror(centroids)
    # plt.plot(cen_plt[0], cen_plt[1], "ks")
    # plt.show()

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
    with open("clustering_stats.txt", "w") as f:
        pass
    for s in load_sizes:
        for _ in range(1):
            subprocess.run(["chmod", "+x", "run.sh"])
            subprocess.run(["./run.sh", f"{s}", "2", "9", "1"])
    with open("clustering_stats.txt", "r") as f:
        lines = f.readlines()
        [print(l) for l in lines]

def plot_cluster_dist():
    colors = ["r", "b", "g", "c", "m", "y"]
    hash = {}
    artists = []
    fig, ax = plt.subplots()
    with open("main/clustering_stats.txt", "r") as f:
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

def test_assignments(out, cs, test_p, alpha, beta):
    # vector_array_n = get_preprocessed_data(mx)

    # _, out, cs = kmeans((4, vector_array_n))
    
    get_last = lambda v: v[-1]
    o_array = np.apply_along_axis(get_last, 1, out)
    save_clustering_parameters(cs, out, o_array)

    # chosen randomly from input records for testing
    incoming_records = np.stack([out[i] for i in np.random.randint(out.shape[0], size=out.shape[0] // (100 // test_p))])
    o_array_test = np.apply_along_axis(get_last, 1, incoming_records)
    incoming_records = np.delete(incoming_records, -1, 1)

    (centroids, stdevs) = get_clustering_parameters()
    assigned_records = np.array([assign_cluster(record, centroids, stdevs, alpha, beta) for record in incoming_records])
    o_array_assigned = np.apply_along_axis(get_last, 1, assigned_records)
    # print(f"Assigned: {o_array_assigned}")
    # print(f"test: {o_array_test}")

    alignment = np.sum(o_array_test == o_array_assigned)
    alignment_p = alignment * 100 / incoming_records.shape[0]
    print(f"Alignment: {alignment_p:.2f}%")
    return alignment_p

def graph_test_assignments():
    
    fig, ax = plt.subplots()
    color = ["r", "g", "b"]
    test_p = 5

    vector_array_n = get_preprocessed_data(sys.argv[1])
    _, out, cs = kmeans((4, vector_array_n))

    x = [v * 0.05 for v in range(18, 24)]
    y = [test_assignments(out, cs, test_p, alpha=1, beta=j) for j in x]
    ax.scatter(x, y)
    ax.set_xlabel("Value of exp. factor applied to n.d. magnitude")
    ax.set_ylabel(f"Assignment accuracy % (relative to clustering, {test_p}% of input data)")
    # plt.title("Accuracy over exp. factor range, 0.1GB records, 4 clusters")
    #plt.legend(["b=" + str(v) for v in rnge])

    x = [v * 0.1 for v in range(25, 30)]
    y = [test_assignments(out, cs, test_p, alpha=j, beta=1) for j in x]
    ax.scatter(x, y)
    ax.set_xlabel("Value of mult. factor applied to n.d. magnitude")
    ax.set_ylabel(f"Assignment accuracy % (relative to clustering, {test_p}% of input data)")
    # plt.title("Accuracy over exp. factor range, 0.1GB records, 4 clusters")
    plt.title(f"{sys.argv[1]} GB")
    plt.legend(["beta range", "alpha range"])
    
    plt.savefig("savefig.png")
    subprocess.run(["sudo", "aws", "s3api", "put-object", "--bucket", "wavecrest-terraform-ops-ew1-ai", "--key", "savefig.png", "--body", "savefig.png"])
    

if __name__ == "__main__":
    graph_test_assignments()