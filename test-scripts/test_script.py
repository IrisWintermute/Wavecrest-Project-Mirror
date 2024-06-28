
# importing library
import numpy as np
import matplotlib.pyplot as plt

graph_data = [(11,0),(7, 4)]

for i in range(10):
    j = i ** 0.8
    graph_data.append((i, j))
graph_data.sort()
graph_array = np.stack(graph_data, axis=0).T
print(graph_array)
(x, y) = tuple(np.split(graph_array, 2, axis=0))
print(x)
print(y)
plt.plot(x[0], y[0])
plt.show()