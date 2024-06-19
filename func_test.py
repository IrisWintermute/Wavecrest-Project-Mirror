from lib import *
import matplotlib.pyplot as plt
import random
import time
import os
import psutil

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
            out.append([c_x, c_y])
    return out

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
        with open("plot.txt", "a") as f:
            f.write("," + str(t)[0:8])
        return result
    return wrapper 

def profile_m_plot(func):
    def wrapper(*args, **kwargs):
        start = process_memory()
        result = func(*args, **kwargs)
        end = process_memory()
        m = end - start
        with open("plot.txt", "a") as f:
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
    data = get_pseudorandom_coords(100, 0, 20, 0, 20, 10, 0.1)
    k_optimal = []
    for k in range(5, 15):
        out, centroids = kmeans(k, data)
        #print("Clustered data and centroids: ")
        #print(centroids)
        chi = optimal_k_decision(out, centroids)
        k_optimal.append([k, chi])
    print(k_optimal)
    optimal_plot = diagonal_mirror(k_optimal)
    plt.plot(optimal_plot[0], optimal_plot[1], "b-")
    plt.show()
    
    # marker = ["ro", "bo", "go", "co", "mo", "yo", "ko","r^", "b^", "g^", "c^", "m^", "y^", "k^"]
    # for i in range(20):
    #     p = [val for val in out if val[-1] == i]
    #     plot = diagonal_mirror(p)
    #     plt.plot(plot[0], plot[1], marker[i % len(marker)])
    # cen_plt = diagonal_mirror(centroids)
    # plt.plot(cen_plt[0], cen_plt[1], "ks")
    # plt.show()

def test_psrndm():
    c = get_pseudorandom_coords(200, 0, 20, 0, 20, 40, 0.1)
    c_p = diagonal_mirror(c)
    plt.plot(c_p[0], c_p[1], "bo")
    plt.show()

def plot_profile():
    with open("plot.txt", "w") as f:
        f.write("")
    x = range(50, 1025, 25)
    data_set = [get_pseudorandom_coords(i, 0, 20, 0, 20, 10, 0.1) for i in x]
    print("Coords generated")
    for i, d in enumerate(data_set):
        _, _ = kmeans(10, d)
        print(x[i])

    x = [v for v in x]
    with open("plot.txt", "r") as f:
        y = f.read().split(",")[1:]
    y = [float(v) for v in y]
    
    with open("plot.txt", "w") as f:
        f.write("")

    for i, d in enumerate(data_set):
        _, _ = kmeans(20, d)
        print(x[i])

    with open("plot.txt", "r") as f:
        y2 = f.read().split(",")[1:]
    y2 = [float(v) for v in y]

    plt.scatter(x, y, color="b")
    plt.scatter(x, y2, color="r")
    #plt.ylim(min(y), max(y))
    #plt.xlim(x[0], x[-1])
    plt.show()

if __name__ == "__main__":
    plot_profile()
