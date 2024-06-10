from lib import *
import matplotlib.pyplot as plt

def get_test_data(name):
    with open(f"test_data_{name}.txt", "r") as f:
        return f.readlines()
    

# || EXTRACT, ENRICH, PREPROCESS AND VECTORISE DATA ||
def test_preporcessing():
    d_raw = get_test_data("cdr")
    d = [record.split(",") + [0] for record in d_raw]
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
    #d_raw = get_test_data("kmeans")
    #d = [[int(v) for v in record.split(",")] + [0] for record in d_raw]
    d = []
    for i in range(7):
        for j in range(7):
            d.append([i, j])
    out, centroids = kmeans(3, d)
    print("Clustered data and centroids: ")
    print(out)
    print(centroids)
    out_plt = diagonal_mirror(out)
    marker = ["ro", "bo", "go"]
    for i in range(3):
        p = [val for val in out if val[-1] == i]
        plot = diagonal_mirror(p)
        plt.plot(plot[0], plot[1], marker[i])
    plt.show()

if __name__ == "__main__":
    test_clustering()