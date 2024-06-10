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
    d_raw = get_test_data("kmeans")
    d = [[int(v) for v in record.split(",")] + [0] for record in d_raw]
    d_plt = diagonal_mirror(d)
    out, centroids = kmeans(3, d)
    print(out)
    print(centroids)

if __name__ == "__main__":
    test_clustering()