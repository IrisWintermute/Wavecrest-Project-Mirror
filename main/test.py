import numpy as np

a = np.arange(12).reshape(3,4)
b = np.apply_over_axes(np.sum, a, 1)
print(a)
print(b)