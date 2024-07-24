import time
import asyncio
import subprocess
import sys
import threading as th

def run():
    subprocess.run(["python", "main/test.py", f"0", f"5"])

d = int(sys.argv[2]) if len(sys.argv) > 2 else 0
r = int(sys.argv[1]) if len(sys.argv) > 1 else 1
if r:
    t1 = th.Thread(target = run)
    t1.start()

time.sleep(int(d))
print("outer" * r + "inner" * (1 - r) + " finished")