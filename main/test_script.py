
# importing library
import numpy as np
 
lst = ["a,f,h,ueq,r,w","d,t,joy,u,igd,d","q,t,io,p,f,y"]
to_r = lambda s: s.split(",")
nlst = list(map(to_r, lst))
print(nlst)
data_array = np.array(nlst)
print(data_array)
print(data_array.ndim)