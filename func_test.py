from lib import *

def get_test_data():
    with open("test_data.txt", "r") as f:
        return f.readlines()
    
d_raw = get_test_data()
d = [record.split(",") + [0] for record in d_raw]

out = [preprocess(r) for r in d]
#print(out)
#print(len(out))
out = diagonal_mirror(out)
out_2 = vectorise(out)
print(diagonal_mirror(out_2))
out_3 = normalise(out_2)
out_3 = diagonal_mirror(out_3)
print(out_3)
