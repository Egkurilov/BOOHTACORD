"""Serve the exact public OpenAPI and pinned Swagger UI on loopback."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[3]
LEAF = Path(__file__).resolve().parent


class Viewer(BaseHTTPRequestHandler):
    def do_GET(self):
        resources = {"/": (LEAF / "index.html", "text/html; charset=utf-8"),
                     "/openapi.json": (ROOT / "contracts/openapi.yaml", "application/json")}
        selected = resources.get(urlsplit(self.path).path)
        if not selected:
            self.send_error(404, "Viewer resource not found")
            return
        path, media_type = selected
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", media_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8081)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Viewer) as server:
        print(f"Swagger viewer: http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
