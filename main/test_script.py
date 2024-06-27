
# importing library
import numpy as np
import matplotlib.pyplot as plt

graph_data = []

for i in range(10):
    j = i ** 0.8
    graph_data.append(np.array([i, j]))
graph_array = np.stack(graph_data, axis=0).T
(x, y) = tuple(np.split(graph_array, 2, axis=0))
print(x)
print(y)
plt.plot(x[0], y[0])
plt.show()