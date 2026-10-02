"""Send one metadata-only OTLP span to the protected collector using stdlib."""

import base64
import pathlib
import secrets
import sys
import time
import urllib.request


def varint(value: int) -> bytes:
    result = bytearray()
    while value > 127:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def item(number: int, value: bytes) -> bytes:
    return varint(number << 3 | 2) + varint(len(value)) + value


def fixed64(number: int, value: int) -> bytes:
    return varint(number << 3 | 1) + value.to_bytes(8, "little")


def payload(trace_id: bytes, span_id: bytes) -> bytes:
    name = item(1, b"service.name")
    value = item(1, b"boohtacord-smoke")
    resource = item(1, item(1, name + item(2, value)))
    scope = item(1, b"smoke")
    started = time.time_ns()
    span = (
        item(1, trace_id)
        + item(2, span_id)
        + item(5, b"collector.smoke")
        + varint(6 << 3)
        + varint(1)
        + fixed64(7, started)
        + fixed64(8, started + 1_000_000)
    )
    scope_spans = item(1, scope) + item(2, span)
    return item(1, resource + item(2, scope_spans))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: smoke_otlp.py PASSWORD_FILE")
    password = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip()
    authorization = base64.b64encode(f"otel:{password}".encode()).decode()
    trace_id = secrets.token_bytes(16)
    request = urllib.request.Request(
        "https://metric.bootybay.ru/v1/traces",
        data=payload(trace_id, secrets.token_bytes(8)),
        headers={
            "Authorization": f"Basic {authorization}",
            "Content-Type": "application/x-protobuf",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        print(f"status={response.status} trace_id={trace_id.hex()}")


if __name__ == "__main__":
    main()
