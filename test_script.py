a = open('num_attributes').read().split(',')
b = open('attributes.txt').read().split(',')

res = list(set(a).difference(set(b)))
            
print(res)
