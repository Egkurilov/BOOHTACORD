"""Check the public asset served by a built web image, rejecting SPA fallbacks."""
import sys
from urllib.request import urlopen


def verify_png(content_type: str, data: bytes) -> None:
    if content_type.split(";", 1)[0].strip().lower() != "image/png":
        raise ValueError("favicon.png has an unexpected Content-Type")
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("favicon.png is not a PNG (possible SPA fallback)")


def main():
    with urlopen(sys.argv[1].rstrip("/") + "/favicon.png", timeout=10) as response:
        if response.status != 200:
            raise ValueError("favicon.png request did not return HTTP 200")
        verify_png(response.headers.get("Content-Type", ""), response.read())
    print("Built-image public PNG smoke passed")


if __name__ == "__main__":
    main()
