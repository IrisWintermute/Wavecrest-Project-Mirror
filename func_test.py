from lib import *

def get_test_data():
    with open("test_data.txt", "r") as f:
        return f.read().split(",")
    
d = get_test_data()
out = preprocess(d)
print(out)
#print(len(out))
out_2 = vectorise([out])
print(out_2)
out_3 = normalise(out_2[0])
print(out_3)
