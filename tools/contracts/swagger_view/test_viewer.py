"""Local HTTP smoke verifies exact bytes and bounded viewer resources."""
from http.server import ThreadingHTTPServer
import json
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import urlopen
from .serve import ROOT, Viewer


class ViewerTest(unittest.TestCase):
    def test_exact_contract_and_private_path_not_served(self):
        with ThreadingHTTPServer(("127.0.0.1", 0), Viewer) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                origin = f"http://127.0.0.1:{server.server_port}"
                with urlopen(origin + "/openapi.json", timeout=5) as response:
                    body = response.read()
                    self.assertEqual((ROOT / "contracts/openapi.yaml").read_bytes(), body)
                    self.assertEqual("no-store", response.headers["Cache-Control"])
                    self.assertEqual("3.1.1", json.loads(body)["openapi"])
                with urlopen(origin + "/", timeout=5) as response:
                    html = response.read().decode()
                    self.assertIn("swagger-ui-dist@5.31.0", html)
                    self.assertIn("supportedSubmitMethods: []", html)
                for path in ("/metrics", "/internal/media-admission", "/../AGENTS.md"):
                    with self.assertRaises(HTTPError) as error:
                        urlopen(origin + path, timeout=5)
                    self.assertEqual(404, error.exception.code)
            finally:
                server.shutdown()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
