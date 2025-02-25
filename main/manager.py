import time
import asyncio
import flow
from lib import assign
import threading as th
import sys

# reading from port on server to collect incoming data
# function to run assign.py and return assessments
# must run alongside main while loop

init_cluster_time = 35 * 60
day = 86400
try: 
    with open("main/data/clustering_parameters.txt", 'x') as f:
    # clustering is executed immediately if no previous clustering data exists
        f.write(str(time.time() - day)) 
except FileExistsError:
    with open("main/data/clustering_parameters.txt", 'w') as f:
        f.write(str(time.time() - day))

with open("ctime.txt", "w") as g:
    g.write(str(day))

def daily_cluster_update():
    """Updates clustering_parameters.txt every 24 hours."""
    def cluster():
        """Runs clustering operation with predetermined k and dataset size in GB."""
        if sys.argv[1]:
            size = float(sys.argv[1])
        else:
            size = 10
        start = time.time()
        print(f"Clustering operation begun at {time.ctime(start)}.")
        flow.main(0, size, 4, 4, 25)
        end = time.time()
        print(f"Finished at {time.ctime(end)} ({(end - start) / 60:.4f} minutes taken).")
        with open("ctime.txt", "w") as f:
            f.write(str(end - start))
        print(f"Cluster data successfully updated. {int(86400 - (time.time() - start))} seconds until next update.")

    def get_time(fname):
        with open(fname, "r") as f:
            return int(str(f.readline()).split(".")[0])
    
    cluster_time = 0
    for i in range(3):
        prev_time = get_time("main/data/clustering_parameters.txt")
        cluster_time = get_time("ctime.txt")
        if time.time() - prev_time >= 86400 - cluster_time:
            c = th.Thread(target = cluster)
            c.start()

        time.sleep(cluster_time * 1.5)

async def handle_echo(reader, writer):
    """Handles incoming CDRs. Passes then to assign() and returns results to sender."""
    data = await reader.read(1024)
    start = time.time()
    record = data.decode()
    addr = writer.get_extra_info('peername')

    # print(f"Received {record} from {addr}")
    result, fraud_hash = assign(record)

    # print(f"Send: {result}, {fraud_hash}")
    wrap = "; ".join([str(result), str(fraud_hash)])
    writer.write(wrap.encode())
    await writer.drain()
    end = time.time()
    # print(f"Record handled and processed in {end - start:.4f} seconds.")
    # print("Closing connection...")
    writer.close()
    await writer.wait_closed()

async def main():
    """Launches server to provide indefinite service on open port."""
    server = await asyncio.start_server(
        handle_echo, '127.0.0.1', 8888)

    addrs = ', '.join(str(sock.getsockname()) for sock in server.sockets)
    print(f'Serving on {addrs}')

    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    # start by spawning daily update logic in separate indefinite thread
    update = th.Thread(target = daily_cluster_update)
    update.start()
    # launch async server to handle incoming requests
    asyncio.run(main())


