"""OpenAPI 3.1 schema validation, in addition to native behavior parity."""
import json
from openapi_spec_validator import validate_spec
from .source import ROOT


def lint(document):
    validate_spec(document)


if __name__ == "__main__":
    lint(json.loads((ROOT / "contracts/openapi.yaml").read_text(encoding="utf-8-sig")))
    print("OpenAPI 3.1 schema lint OK.")
