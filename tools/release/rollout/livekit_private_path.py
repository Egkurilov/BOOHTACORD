#!/usr/bin/env python3
"""Restore and preflight the private API-to-LiveKit RoomService path."""
import base64
import hashlib
import hmac
import http.client
import ipaddress
import json
import os
import secrets
import socket
import struct
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import urlsplit

TWIRP_ERROR_CODES = {
    "canceled", "invalid_argument", "deadline_exceeded", "not_found", "already_exists",
    "permission_denied", "resource_exhausted", "failed_precondition", "aborted",
    "out_of_range", "unauthenticated", "internal", "unavailable", "data_loss", "unknown",
}
SAFE_PROBE_CODES = TWIRP_ERROR_CODES | {
    "private_endpoint_mismatch", "dns_query_failed", "dns_no_ipv4", "dns_rcode_2",
    "invalid_dns_response", "ConnectionRefusedError", "ConnectionResetError",
    "TimeoutError", "HTTPException", "invalid_response", "invalid_input", "other",
}


def output(*command):
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError as error:
        raise RuntimeError("Docker inspection failed") from error


def read_json(phase, *command):
    try:
        return json.loads(output(*command))
    except (TypeError, ValueError, RuntimeError) as error:
        raise RuntimeError(phase) from error


def run_checked(phase, command):
    try:
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as error:
        raise RuntimeError(phase) from error


def container_ids(project, service):
    result = output(
        "docker", "ps", "-q",
        "--filter", f"label=com.docker.compose.project={project}",
        "--filter", f"label=com.docker.compose.service={service}",
    )
    ids = result.splitlines() if result else []
    if len(ids) != 1:
        raise RuntimeError(f"expected exactly one running {service} container")
    return ids[0]


def inspect_labels(container_id, service, project):
    labels = read_json(
        f"{service} container identity inspection failed",
        "docker", "inspect", "--format", "{{json .Config.Labels}}", container_id,
    )
    if (not isinstance(labels, dict)
            or labels.get("com.docker.compose.project") != project
            or labels.get("com.docker.compose.service") != service):
        raise RuntimeError(f"{service} container identity does not match the Compose project")


def inspect_networks(container_id, service):
    return read_json(
        f"{service} network inspection failed",
        "docker", "inspect", "--format", "{{json .NetworkSettings.Networks}}", container_id,
    )


def ensure_livekit_private_alias(project, network_name, container_id=None):
    if container_id is None:
        container_id = container_ids(project, "livekit")
    inspect_labels(container_id, "livekit", project)
    networks = inspect_networks(container_id, "livekit")
    endpoint = networks.get(network_name)
    if endpoint is None:
        run_checked(
            "LiveKit private endpoint connect failed",
            ["docker", "network", "connect", "--alias", "livekit", network_name, container_id],
        )
    elif "livekit" not in (endpoint.get("Aliases") or []):
        run_checked(
            "LiveKit private endpoint disconnect failed",
            ["docker", "network", "disconnect", network_name, container_id],
        )
        run_checked(
            "LiveKit private service alias reconnect failed",
            ["docker", "network", "connect", "--alias", "livekit", network_name, container_id],
        )
    refreshed = inspect_networks(container_id, "livekit").get(network_name)
    if refreshed is None or "livekit" not in (refreshed.get("Aliases") or []):
        raise RuntimeError("LiveKit service alias is not present on the private network")


def skip_dns_name(packet, offset):
    while True:
        if offset >= len(packet):
            raise RuntimeError("truncated DNS name")
        length = packet[offset]
        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(packet):
                raise RuntimeError("truncated DNS compression pointer")
            return offset + 2
        if length & 0xC0:
            raise RuntimeError("invalid DNS label")
        offset += 1
        if length == 0:
            return offset
        offset += length


def parse_dns_a_response(packet, query_id):
    if len(packet) < 12:
        raise RuntimeError("truncated DNS response")
    response_id, flags, question_count, answer_count, _, _ = struct.unpack("!HHHHHH", packet[:12])
    if response_id != query_id:
        raise RuntimeError("DNS response id mismatch")
    if not flags & 0x8000:
        raise RuntimeError("DNS packet is not a response")
    rcode = flags & 0x000F
    if rcode:
        raise RuntimeError(f"DNS response code {rcode}")
    offset = 12
    for _ in range(question_count):
        offset = skip_dns_name(packet, offset)
        if offset + 4 > len(packet):
            raise RuntimeError("truncated DNS question")
        offset += 4
    addresses = []
    for _ in range(answer_count):
        offset = skip_dns_name(packet, offset)
        if offset + 10 > len(packet):
            raise RuntimeError("truncated DNS answer")
        record_type, record_class, _, size = struct.unpack("!HHIH", packet[offset:offset + 10])
        offset += 10
        if offset + size > len(packet):
            raise RuntimeError("truncated DNS record data")
        value = packet[offset:offset + size]
        offset += size
        if record_type == 1 and record_class == 1 and size == 4:
            addresses.append(socket.inet_ntoa(value))
    if not addresses:
        raise RuntimeError("DNS response has no IPv4 address")
    return addresses


def resolve_docker_service(host):
    labels = host.rstrip(".").split(".")
    if not labels or any(not label or len(label) > 63 for label in labels):
        raise RuntimeError("invalid LiveKit service hostname")
    query_id = secrets.randbelow(65536)
    qname = b"".join(bytes((len(label),)) + label.encode("ascii") for label in labels) + b"\x00"
    query = struct.pack("!HHHHHH", query_id, 0x0100, 1, 0, 0, 0) + qname + struct.pack("!HH", 1, 1)
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.settimeout(2)
    try:
        client.sendto(query, ("127.0.0.11", 53))
        response, _ = client.recvfrom(4096)
    except OSError as error:
        raise RuntimeError("Docker DNS query failed") from error
    finally:
        client.close()
    return parse_dns_a_response(response, query_id)


def encode_jwt_part(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def room_list_token(key, secret):
    now = int(time.time())
    header = encode_jwt_part(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    payload = encode_jwt_part(json.dumps({
        "iss": key,
        "sub": "voice-platform-private-preflight",
        "nbf": now,
        "exp": now + 60,
        "video": {"roomList": True},
    }, separators=(",", ":")).encode())
    unsigned = header + "." + payload
    signature = hmac.new(secret.encode(), unsigned.encode(), hashlib.sha256).digest()
    return unsigned + "." + encode_jwt_part(signature)


def probe_room_service(payload):
    host = payload["host"]
    port = int(payload["port"])
    expected_ip = str(ipaddress.ip_address(payload["private_ip"]))
    addresses = resolve_docker_service(host)
    if set(addresses) != {expected_ip}:
        return {"ok": False, "phase": "dns", "code": "private_endpoint_mismatch"}

    dummy = "voice:" + str(uuid.uuid4())
    body = json.dumps({"names": [dummy]}, separators=(",", ":")).encode()
    connection = http.client.HTTPConnection(addresses[0], port, timeout=3)
    try:
        connection.request("POST", "/twirp/livekit.RoomService/ListRooms", body=body, headers={
            "Host": f"{host}:{port}",
            "Authorization": "Bearer " + room_list_token(payload["api_key"], payload["api_secret"]),
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
        response = connection.getresponse()
        response_body = response.read(65536)
    except (OSError, http.client.HTTPException) as error:
        return {"ok": False, "phase": "roomservice", "code": type(error).__name__}
    finally:
        connection.close()
    if response.status != 200:
        try:
            error_code = json.loads(response_body).get("code", "")
        except (TypeError, ValueError):
            error_code = ""
        if not isinstance(error_code, str) or error_code not in TWIRP_ERROR_CODES:
            error_code = "other"
        return {"ok": False, "phase": "roomservice", "status": response.status, "code": error_code}
    try:
        result = json.loads(response_body)
        rooms = result.get("rooms", [])
        if not isinstance(rooms, list):
            raise ValueError
    except (TypeError, ValueError):
        return {"ok": False, "phase": "roomservice", "code": "invalid_response"}
    matching_rooms = sum(1 for room in rooms if isinstance(room, dict) and room.get("name") == dummy)
    return {"ok": matching_rooms == 0, "phase": "roomservice", "status": 200,
            "matching_dummy_rooms": matching_rooms}


def probe_api_network_namespace(api_pid, payload):
    command = ["nsenter", "--target", str(api_pid), "--net", sys.executable,
               str(Path(__file__).resolve()), "--probe"]
    environment = os.environ.copy()
    for name in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        environment.pop(name, None)
    try:
        result = subprocess.run(command, input=json.dumps(payload), text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                timeout=8, check=False, env=environment)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("API network namespace RoomService probe could not run") from error
    try:
        response = json.loads(result.stdout)
    except (TypeError, ValueError) as error:
        raise RuntimeError("API network namespace RoomService probe returned invalid output") from error
    if not isinstance(response, dict):
        raise RuntimeError("API network namespace RoomService probe returned invalid output")
    if result.returncode != 0 or response.get("ok") is not True:
        phase = response.get("phase", "unknown")
        phase = phase if isinstance(phase, str) and phase in {"dns", "roomservice", "probe"} else "unknown"
        code = response.get("code", "other")
        code = code if isinstance(code, str) and code in SAFE_PROBE_CODES else "other"
        status = response.get("status")
        detail = f"{phase} {code}"
        if isinstance(status, int):
            detail += f" HTTP {status}"
        raise RuntimeError("LiveKit private RoomService preflight failed (" + detail + ")")


def environment_map(container_id, service):
    values = read_json(
        f"{service} environment inspection failed",
        "docker", "inspect", "--format", "{{json .Config.Env}}", container_id,
    )
    result = {}
    for item in values:
        name, separator, value = item.partition("=")
        if separator:
            result[name] = value
    return result


def ensure_current_livekit_private_path(project_dir):
    project_dir = Path(project_dir).resolve()
    compose_dir = project_dir / "deploy" if (project_dir / "deploy/compose.yaml").is_file() else project_dir
    compose = ["docker", "compose", "--project-directory", str(compose_dir), "--env-file",
               str(project_dir / ".env"), "-f", str(compose_dir / "compose.yaml")]
    configuration = read_json("deployment Compose configuration could not be read",
                              *compose, "config", "--format", "json")
    project = configuration.get("name", "voice-platform")
    services = configuration.get("services", {})
    if not isinstance(services, dict) or "api" not in services or "livekit" not in services:
        raise RuntimeError("deployment Compose configuration lacks API or LiveKit service")
    networks = configuration.get("networks", {})
    if not isinstance(networks, dict):
        raise RuntimeError("deployment private network configuration is unavailable")
    network_config = networks.get("private", {})
    if not isinstance(network_config, dict):
        raise RuntimeError("deployment private network configuration is invalid")
    network_name = network_config.get("name") or f"{project}_private"

    api_id = container_ids(project, "api")
    livekit_id = container_ids(project, "livekit")
    inspect_labels(api_id, "api", project)
    inspect_labels(livekit_id, "livekit", project)
    api_networks = inspect_networks(api_id, "api")
    api_private = api_networks.get(network_name)
    if api_private is None:
        raise RuntimeError("API container is not attached to the private network")
    api_pid = read_json("API process inspection failed", "docker", "inspect",
                        "--format", "{{.State.Pid}}", api_id)
    if not isinstance(api_pid, int):
        try:
            api_pid = int(api_pid)
        except (TypeError, ValueError) as error:
            raise RuntimeError("API process id is invalid") from error

    ensure_livekit_private_alias(project, network_name, livekit_id)
    livekit_networks = inspect_networks(livekit_id, "livekit")
    livekit_private = livekit_networks.get(network_name)
    if livekit_private is None:
        raise RuntimeError("LiveKit container is not attached to the private network")
    private_ip = livekit_private.get("IPAddress", "")
    api_env = environment_map(api_id, "api")
    livekit_env = environment_map(livekit_id, "livekit")
    api_key = api_env.get("LIVEKIT_API_KEY", "")
    api_secret = api_env.get("LIVEKIT_API_SECRET", "")
    if (not api_key or not api_secret
            or not hmac.compare_digest(api_key, livekit_env.get("LIVEKIT_API_KEY", ""))
            or not hmac.compare_digest(api_secret, livekit_env.get("LIVEKIT_API_SECRET", ""))):
        raise RuntimeError("API and LiveKit credentials are absent or do not match")

    endpoint = urlsplit(api_env.get("LIVEKIT_PRIVATE_HTTP_URL", "http://livekit:7880"))
    if (endpoint.scheme != "http" or endpoint.hostname is None or endpoint.port not in (None, 7880)
            or endpoint.path not in ("", "/") or endpoint.query or endpoint.fragment):
        raise RuntimeError("LIVEKIT_PRIVATE_HTTP_URL is not the expected private HTTP endpoint")
    probe_api_network_namespace(api_pid, {
        "host": endpoint.hostname,
        "port": endpoint.port or 7880,
        "private_ip": private_ip,
        "api_key": api_key,
        "api_secret": api_secret,
    })


def probe_child_main():
    try:
        result = probe_room_service(json.load(sys.stdin))
    except RuntimeError as error:
        message = str(error)
        if message.startswith("DNS response code ") and message.removeprefix("DNS response code ").isdigit():
            rcode = int(message.removeprefix("DNS response code "))
            code = f"dns_rcode_{rcode}" if rcode == 2 else "invalid_dns_response"
        elif message == "DNS response has no IPv4 address":
            code = "dns_no_ipv4"
        elif message == "Docker DNS query failed":
            code = "dns_query_failed"
        else:
            code = "invalid_dns_response"
        result = {"ok": False, "phase": "dns", "code": code}
    except (KeyError, TypeError, ValueError):
        result = {"ok": False, "phase": "probe", "code": "invalid_input"}
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result.get("ok") is True else 1


def main(argv):
    if argv[1:] == ["--probe"]:
        return probe_child_main()
    if len(argv) != 2:
        print("usage: livekit_private_path.py PROJECT_DIR", file=sys.stderr)
        return 2
    try:
        ensure_current_livekit_private_path(argv[1])
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.TimeoutExpired) as error:
        detail = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print(f"LiveKit private path preflight failed: {detail}.", file=sys.stderr)
        return 1
    print("LiveKit private DNS and authenticated RoomService preflight passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
