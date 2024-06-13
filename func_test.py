from lib import *
import matplotlib.pyplot as plt
import random

def get_test_data(name):
    with open(f"test_data_{name}.txt", "r") as f:
        return f.readlines()
        
def get_pseudorandom_coordinates(n, x0, xm, y0, ym, k, v):
    out = []
    for _ in range(k):
        c = (random.random() * (xm - x0) + x0, random.random() * (ym - y0) + y0)
        for _ in range(n // k):
            (c_x, c_y) = c
            c_x = random.gauss(c_x, v)
            c_y = random.gauss(c_y, v)
            out.append([c_x, c_y])
    return out

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
    data = get_pseudorandom_coordinates(200, 0, 20, 0, 20, 40, 0.1)
    k_optimal = []
    for k in range(9, 100):
        out, centroids = kmeans(k, data)
        #print("Clustered data and centroids: ")
        #print(centroids)
        chi = optimal_k_decision(out, centroids)
        k_optimal.append([k, chi])
    optimal_plot = diagonal_mirror(k_optimal)
    plt.plot(optimal_plot[0], optimal_plot[1], "b-")
    plt.show()
    
    marker = ["ro", "bo", "go", "co", "mo", "yo", "ko","r^", "b^", "g^", "c^", "m^", "y^", "k^"]
    for i in range(8):
        p = [val for val in out if val[-1] == i]
        plot = diagonal_mirror(p)
        plt.plot(plot[0], plot[1], marker[i % len(marker)])
    cen_plt = diagonal_mirror(centroids)
    plt.plot(cen_plt[0], cen_plt[1], "ks")
    plt.show()
    

if __name__ == "__main__":
    test_clustering()
