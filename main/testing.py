import numpy as np

t = lambda a: np.array([a]).T
grid = np.arange(0, 16).reshape(4, 4)
print(grid)
print(t(grid[:,2]))