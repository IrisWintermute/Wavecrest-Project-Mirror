from lib import *
import matplotlib.pyplot as plt
import random
import subprocess

marker = ["ro", "bo", "go", "co", "mo", "yo", "ko","r^", "b^", "g^", "c^", "m^", "y^", "k^"]

def get_test_data(name):
    with open(f"test_data_{name}.txt", "r") as f:
        return f.readlines()
        
def get_pseudorandom_coords(n, x0, xm, y0, ym, k, v):
    out = []
    for _ in range(k):
        c = (random.random() * (xm - x0) + x0, random.random() * (ym - y0) + y0)
        for _ in range(n // k):
            (c_x, c_y) = c
            c_x = random.gauss(c_x, v)
            c_y = random.gauss(c_y, v)
            out.append(np.array([c_x, c_y]))
    return np.array(out)


# || EXTRACT, ENRICH, PREPROCESS AND VECTORISE DATA ||
def test_preprocessing():
    d_raw = get_test_data("cdr")
    d = [record.split(",") for record in d_raw]
    out = [preprocess(r) for r in d]
    #print(out)
    #print(len(out))
    out = diagonal_mirror(out)
    out_2 = vectorise(out)
    #print(diagonal_mirror(out_2))
    out_3 = normalise(out_2)
    out_3 = diagonal_mirror(out_3)
    #print(out_3)

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
            


def test_psrndm():
    c = get_pseudorandom_coords(200, 0, 20, 0, 20, 40, 0.1)
    c_p = diagonal_mirror(c)
    plt.plot(c_p[0], c_p[1], "bo")
    plt.show()

def plot_profile():

    '''
    x = range(50, 5050, 50)
    data_set = [get_pseudorandom_coords(i, 0, 20, 0, 20, 10, 0.1) for i in x]
    print("Coords generated")
    x = [v for v in x]

    k_range = [5, 10, 20]
    for j, k in enumerate(k_range):
        with open("main/data/plot.txt", "w") as f:
            f.write("")

        for i, d in enumerate(data_set):
            , _, _ = kmeans(k, d)
            print(x[i])

        with open("main/data/plot.txt", "r") as f:
            y = f.read().split(",")[1:]
        y = [float(v) for v in y]
        plt.scatter(x, y, color=marker[j][0])

    plt.legend([f"k={k}" for k in k_range], loc="upper right")
    plt.show()
    '''
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

def regex_test():
    string = '"horse,donkey",mule,0,6,"",petrol,"camel, spine"'
    comma_str = re.findall('"[^,"]+,[^,"]+"', string)
    hyphen_str = [re.sub(',', '-', s) for s in comma_str]
    for i, h in enumerate(hyphen_str):
        string = re.sub(comma_str[i], h, string)
    print(string)

def cluster_size_dist():
    load_sizes = [0.5, 0.75, 1]
    with open("clustering_stats.txt", "w") as f:
        pass
    for s in load_sizes:
        for _ in range(3):
            subprocess.run(["chmod", "+x", "run.sh"])
            subprocess.run(["./run.sh", f"{s}", "2", "9", "1"])
    with open("clustering_stats.txt", "r") as f:
        lines = f.readlines()
        [print(l) for l in lines]

    


if __name__ == "__main__":
    cluster_size_dist()


# to remove
# EG Codec, IG Codec
# EG dest group
# PDD
# ReleaseSource
# Row Type
# RTP Media