from lib import *

def get_test_data():
    with open("test_data.txt", "r") as f:
        return f.read()
    
d_raw = get_test_data()
d = [[attribute for attribute in record.split(",")].append(0) for record in d_raw.split("\n")]
out = [preprocess(r) for r in d]
print(out)
#print(len(out))
out_2 = vectorise(out)
print(out_2)
out_3 = [normalise(r) for r in out_2]
print(out_3)
