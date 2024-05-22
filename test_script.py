
import sys
path_to_file = sys.argv[1]
with open(path_to_file, "r") as file:
    string = file.read()
with open('output.txt', "w") as file:
    file.write(string + " processed with Python")