"""Bounded loopback bridge to an isolated WSL QA database, never a public listener."""
import argparse
import ipaddress
import select
import socket
import threading
import time


def bridge(incoming, host, port, deadline):
    try:
        with incoming, socket.create_connection((host, port), timeout=3) as outgoing:
            while time.monotonic() < deadline:
                ready, _, _ = select.select([incoming, outgoing], [], [], 1)
                for source in ready:
                    data = source.recv(65536)
                    if not data:
                        return
                    (outgoing if source is incoming else incoming).sendall(data)
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('private_qa_host')
    parser.add_argument('--target-port', type=int, default=15432)
    parser.add_argument('--listen-port', type=int, default=15433)
    parser.add_argument('--seconds', type=int, default=900)
    args = parser.parse_args()
    ip = ipaddress.ip_address(args.private_qa_host)
    if not ip.is_private or not 1 <= args.seconds <= 3600:
        parser.error('private synthetic QA host and bounded lifetime required')
    if not all(1024 <= p <= 65535 for p in (args.target_port, args.listen_port)):
        parser.error('unprivileged ports required')
    deadline = time.monotonic() + args.seconds
    workers = []
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', args.listen_port))
        listener.listen(8)
        listener.settimeout(1)
        while time.monotonic() < deadline:
            try:
                connection, _ = listener.accept()
            except socket.timeout:
                continue
            workers = [w for w in workers if w.is_alive()]
            if len(workers) >= 32:
                connection.close()
                continue
            worker = threading.Thread(target=bridge, args=(connection, str(ip), args.target_port, deadline), daemon=True)
            worker.start()
            workers.append(worker)


if __name__ == '__main__':
    main()
