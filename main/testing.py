

l_dim = 5
hash = {}
for i in range(l_dim):
    for j in range(l_dim):
        if i != j and not (hash.get((i, j))):
            print(f"{i} - {j}")
            hash[(i, j)] = 1