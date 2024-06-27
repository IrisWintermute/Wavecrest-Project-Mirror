from multiprocessing import Pool, Lock
import os


def get_out(wrap):
    (x, y) = wrap
    return x ** y

def main():
    cores = os.cpu_count()
    out = 0
    k_range = [(k, 2) for k in range(20)]
    lock = Lock()

    with Pool(processes=cores) as p:
        for i in p.imap_unordered(get_out, k_range):
            with lock:
                if i > out:
                    out = i

    print(out)

if __name__ == "__main__":
    main()

