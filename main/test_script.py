
# importing library
import numpy as np
 
# initializing list
lst = np.arange(20).reshape(4,5)
print(lst)

arr = np.apply_along_axis(np.average, 0, lst)

print(arr)