from lib import *

def get_test_data():
    with open("test_data.txt", "r") as f:
        return f.readlines()
    
d_raw = get_test_data()
d = [record.split(",") + [0] for record in d_raw]
print(d)
"""
out = [preprocess(r) for r in d]
print(out)
#print(len(out))
out_2 = vectorise(out)
print(out_2)
out_3 = [normalise(r) for r in out_2]
print(out_3)
"""