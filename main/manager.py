import time
import asyncio
import flow
from lib import assign
import threading as th

# reading from port on server to collect incoming data
# function to run assign.py and return assessments
# must run alongside main while loop

def daily_cluster_update():
    def cluster():
        start = time.time()
        print(f"Clustering operation begun at {time.ctime(start)}.")
        # default read size of 10 GB
        # testing with 0.05 GB
        # flow.main(0, 0.05, 4, 4)
        with open("clustering_stats.txt", "w") as f:
            f.write(str(start))
        end = time.time()
        print(f"Clustering operation finished at {time.ctime(end)} ({(end - start) / 60:.4f} minutes taken).")
        with open("ctime.txt", "w") as f:
            f.write(str(end - start))

    def get_time(fname):
        with open(fname, "r") as f:
            return int(f.readline())
    
    cluster_time = 0
    while True:
        prev_time = get_time("clustering_stats.txt")
        cluster_time = get_time("ctime.txt")
        if time.time() - prev_time >= 30 - cluster_time:
            c = th.Thread(target = cluster)
            c.start()

        time.sleep(5)

async def handle_echo(reader, writer):
    data = await reader.read(1024)
    record = data.decode()
    addr = writer.get_extra_info('peername')

    print(f"Received {record} from {addr}")

    # result = assign(record)
    with open("clustering_stats.txt", "r") as f:
        result = record + f.read()

    print(f"Send: {record}")
    writer.write(result.encode())
    await writer.drain()

    print("Close the connection")
    writer.close()
    await writer.wait_closed()

async def main():
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


