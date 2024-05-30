


with open("attributes.txt", "r") as file:
    attributes = file.read().split(",")
with open("persistent_attributes.txt", "r") as file:
    persist = file.read().split(",")

print(attributes)
print(persist)