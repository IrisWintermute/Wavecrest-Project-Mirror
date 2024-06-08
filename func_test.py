from lib import *

def get_test_data():
    with open("test_data.txt", "r") as f:
        return f.read().split(",")
    
def main():
    d = get_test_data()
    out = preprocess(d)
    print(out)
    print(len(out))

if __name__ == "__main__": 
    main()