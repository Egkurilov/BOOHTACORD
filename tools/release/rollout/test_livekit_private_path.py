import importlib.util
import json
import socket
import struct
import sys
import unittest
from pathlib import Path
from unittest.mock import call, patch


SCRIPT = Path(__file__).with_name("livekit_private_path.py")
SPEC = importlib.util.spec_from_file_location("livekit_private_path", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def livekit_labels(project="voice-platform", service="livekit"):
    return json.dumps({
        "com.docker.compose.project": project,
        "com.docker.compose.service": service,
    })


def network_state(aliases):
    return json.dumps({"voice-platform_private": {
        "IPAddress": "172.19.0.6",
        "Aliases": aliases,
    }})


def dns_response(address="172.19.0.6", rcode=0):
    query_id = 0x1234
    qname = b"\x07livekit\x00"
    question = qname + struct.pack("!HH", 1, 1)
    answer = b""
    answer_count = 0
    if address:
        answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 30, 4) + socket.inet_aton(address)
        answer_count = 1
    flags = 0x8180 | rcode
    return struct.pack("!HHHHHH", query_id, flags, 1, answer_count, 0, 0) + question + answer


class LiveKitPrivateAliasTests(unittest.TestCase):
    def test_restores_missing_alias_on_existing_private_endpoint(self):
        with patch.object(MODULE, "output", side_effect=[
            livekit_labels(),
            network_state(["voice-platform-livekit-1"]),
            network_state(["voice-platform-livekit-1", "livekit"]),
        ]), patch.object(MODULE, "run_checked") as run:
            MODULE.ensure_livekit_private_alias("voice-platform", "voice-platform_private", "livekit-id")

        self.assertEqual(run.call_args_list, [
            call("LiveKit private endpoint disconnect failed", [
                "docker", "network", "disconnect", "voice-platform_private", "livekit-id",
            ]),
            call("LiveKit private service alias reconnect failed", [
                "docker", "network", "connect", "--alias", "livekit",
                "voice-platform_private", "livekit-id",
            ]),
        ])

    def test_attaches_livekit_with_alias_when_private_endpoint_is_missing(self):
        with patch.object(MODULE, "output", side_effect=[
            livekit_labels(),
            json.dumps({}),
            network_state(["livekit"]),
        ]), patch.object(MODULE, "run_checked") as run:
            MODULE.ensure_livekit_private_alias("voice-platform", "voice-platform_private", "livekit-id")

        run.assert_called_once_with(
            "LiveKit private endpoint connect failed",
            ["docker", "network", "connect", "--alias", "livekit",
             "voice-platform_private", "livekit-id"],
        )

    def test_does_not_reconnect_when_private_alias_is_present(self):
        with patch.object(MODULE, "output", side_effect=[
            livekit_labels(),
            network_state(["livekit"]),
            network_state(["livekit"]),
        ]), patch.object(MODULE, "run_checked") as run:
            MODULE.ensure_livekit_private_alias("voice-platform", "voice-platform_private", "livekit-id")

        run.assert_not_called()

    def test_rejects_container_from_another_service_before_network_mutation(self):
        with patch.object(MODULE, "output", side_effect=[
            livekit_labels(service="api"),
        ]), patch.object(MODULE, "run_checked") as run:
            with self.assertRaises(RuntimeError):
                MODULE.ensure_livekit_private_alias("voice-platform", "voice-platform_private", "unexpected-id")

        run.assert_not_called()

    def test_rejects_ambiguous_livekit_service(self):
        with patch.object(MODULE, "output", return_value="one\ntwo") as output, patch.object(MODULE, "run_checked") as run:
            with self.assertRaises(RuntimeError):
                MODULE.ensure_livekit_private_alias("voice-platform", "voice-platform_private")

        output.assert_called_once()
        run.assert_not_called()


class DockerDNSParserTests(unittest.TestCase):
    def test_reads_ipv4_answer_for_livekit_alias(self):
        self.assertEqual(MODULE.parse_dns_a_response(dns_response(), 0x1234), ["172.19.0.6"])

    def test_rejects_dns_servfail(self):
        with self.assertRaisesRegex(RuntimeError, "DNS response code 2"):
            MODULE.parse_dns_a_response(dns_response(address=None, rcode=2), 0x1234)

    def test_rejects_response_with_wrong_query_id(self):
        with self.assertRaisesRegex(RuntimeError, "DNS response id mismatch"):
            MODULE.parse_dns_a_response(dns_response(), 0x9999)


class RoomServiceProbeTests(unittest.TestCase):
    def test_probe_uses_only_a_dummy_room_and_room_list_grant(self):
        connections = []

        class Response:
            status = 200

            @staticmethod
            def read(_limit):
                return b'{"rooms":[]}'

        class Connection:
            request_args = None

            def __init__(self, host, port, timeout):
                self.host, self.port, self.timeout = host, port, timeout
                connections.append(self)

            def request(self, *args, **kwargs):
                self.request_args = (args, kwargs)

            @staticmethod
            def getresponse():
                return Response()

            @staticmethod
            def close():
                pass

        with patch.object(MODULE, "resolve_docker_service", return_value=["172.19.0.6"]), \
                patch.object(MODULE.http.client, "HTTPConnection", Connection):
            result = MODULE.probe_room_service({
                "host": "livekit",
                "port": 7880,
                "private_ip": "172.19.0.6",
                "api_key": "test-key",
                "api_secret": "test-secret",
            })

        self.assertEqual(result, {
            "ok": True, "phase": "roomservice", "status": 200, "matching_dummy_rooms": 0,
        })
        request_args, request_kwargs = connections[0].request_args
        self.assertEqual(request_args[:2], ("POST", "/twirp/livekit.RoomService/ListRooms"))
        names = json.loads(request_kwargs["body"])["names"]
        self.assertEqual(len(names), 1)
        self.assertRegex(names[0], r"^voice:[0-9a-f-]{36}$")
        token = MODULE.room_list_token("test-key", "test-secret")
        claims = json.loads(MODULE.base64.urlsafe_b64decode(token.split(".")[1] + "=="))
        self.assertEqual(claims["video"], {"roomList": True})

    def test_namespace_probe_passes_runtime_credentials_only_over_stdin(self):
        payload = {
            "host": "livekit", "port": 7880, "private_ip": "172.19.0.6",
            "api_key": "test-key", "api_secret": "test-secret",
        }
        completed = MODULE.subprocess.CompletedProcess([], 0, '{"ok":true}', "")
        with patch.object(MODULE.subprocess, "run", return_value=completed) as run:
            MODULE.probe_api_network_namespace(1234, payload)

        args, kwargs = run.call_args
        self.assertIn("nsenter", args[0])
        self.assertNotIn("test-key", " ".join(args[0]))
        self.assertNotIn("test-secret", " ".join(args[0]))
        self.assertEqual(json.loads(kwargs["input"]), payload)
        self.assertNotIn("HTTP_PROXY", kwargs["env"])

    def test_namespace_probe_reports_only_bounded_failure_details(self):
        payload = {
            "host": "livekit", "port": 7880, "private_ip": "172.19.0.6",
            "api_key": "test-key", "api_secret": "test-secret",
        }
        completed = MODULE.subprocess.CompletedProcess(
            [], 1, '{"ok":false,"phase":"dns","code":"dns_rcode_2"}', "",
        )
        with patch.object(MODULE.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(RuntimeError, "dns dns_rcode_2") as raised:
                MODULE.probe_api_network_namespace(1234, payload)

        self.assertNotIn("test-secret", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
