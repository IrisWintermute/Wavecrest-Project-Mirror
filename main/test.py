import time
import asyncio
import subprocess
import sys
import threading as th

async def handle_echo(reader, writer):
    data = await reader.read(-1)
    record = data.decode()
    addr = writer.get_extra_info('peername')

    print(f"Received {record} from {addr}")

    result = record

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
    # launch async server to handle incoming requests
    asyncio.run(main())