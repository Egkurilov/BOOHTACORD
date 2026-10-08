"""Mutation tests reject contract drift using independently parsed native routes."""
import copy
import json
import unittest
from .source import ROOT, PRIVATE, key, routes
from .validate import validate


class ParityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.native = routes()
        cls.contract = json.loads((ROOT / "contracts/openapi.yaml").read_text(encoding="utf-8-sig"))

    def setUp(self):
        self.document = copy.deepcopy(self.contract)

    def operation(self, path="/api/v1/me", method="get"):
        return self.document["paths"][path][method]

    def rejected(self, reason):
        with self.assertRaisesRegex(ValueError, reason):
            validate(self.document, self.native)

    def test_current_native_contract(self):
        public_count = sum(key(route) not in PRIVATE for route in self.native)
        self.assertEqual(public_count, validate(self.document, self.native))

    def test_removed_operation(self):
        del self.document["paths"]["/api/v1/me"]["get"]
        self.rejected("route parity")

    def test_new_native_route(self):
        new = dict(self.native[0], method="GET", path="/api/v1/new-route")
        with self.assertRaisesRegex(ValueError, "route parity"):
            validate(self.document, [*self.native, new])

    def test_wrong_session_boundary(self):
        self.operation()["security"] = []
        self.rejected("security parity")

    def test_anonymous_logout_and_optional_session(self):
        for path, method in (("/api/v1/auth/logout", "post"), ("/api/v1/auth/session", "get")):
            with self.subTest(path=path):
                self.setUp()
                self.operation(path, method)["security"] = [{"SessionCookie": []}]
                self.rejected("security parity")

    def test_missing_path_parameter(self):
        self.operation("/api/v1/members/{userID}")["parameters"] = []
        self.rejected("parameter parity")

    def test_missing_query_parameter(self):
        self.operation("/api/v1/realtime")["parameters"] = [
            p for p in self.operation("/api/v1/realtime")["parameters"] if p["name"] != "capabilities"]
        self.rejected("parameter parity")

    def test_origin_must_be_required(self):
        for parameter in self.operation("/api/v1/me", "patch")["parameters"]:
            if parameter["name"] == "Origin":
                parameter["required"] = False
        self.rejected("required parameter")

    def test_invented_parameter(self):
        self.operation()["parameters"] = [{"name": "made-up", "in": "query", "schema": {"type": "string"}}]
        self.rejected("parameter parity")

    def test_relay_empty_error_cannot_promise_json(self):
        self.operation("/api/v1/telemetry/traces", "post")["responses"]["413"]["content"] = {
            "application/json": {"schema": {"$ref": "#/components/schemas/Error"}}}
        self.rejected("must have empty body")

    def test_flat_client_update_error(self):
        self.operation("/api/v1/client-updates")["responses"]["400"]["content"]["application/json"]["schema"] = {
            "$ref": "#/components/schemas/Error"}
        self.rejected("flat client-update error")

    def test_missing_request_id(self):
        del self.operation()["responses"]["200"]["headers"]["X-Request-ID"]
        self.rejected("request ID")

    def test_private_route_is_not_public(self):
        self.document["paths"]["/metrics"] = {"get": copy.deepcopy(self.operation())}
        self.rejected("route parity")

    def test_optional_session_wire_body(self):
        from jsonschema import Draft202012Validator
        schema = self.document["components"]["schemas"]["SessionStatus"]
        validator = Draft202012Validator(schema)
        self.assertTrue(validator.is_valid({"authenticated": False}))
        self.assertTrue(validator.is_valid({"authenticated": True, "account_id": "account", "role": "MEMBER"}))
        self.assertFalse(validator.is_valid({"account_id": "account", "role": "MEMBER"}))
        self.assertFalse(validator.is_valid({"authenticated": True}))

    def test_optional_session_wrong_success_schema(self):
        self.operation("/api/v1/auth/session")["responses"]["200"]["content"]["application/json"]["schema"] = {
            "$ref": "#/components/schemas/Principal"}
        self.rejected("optional session success body")


if __name__ == "__main__":
    unittest.main()
