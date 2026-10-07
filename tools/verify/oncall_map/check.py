"""Fail closed when the operator map loses a flow or its exact source baseline."""
from pathlib import Path
from .anchors import ANCHORS, FORBIDDEN

DOCUMENT = "docs/operations/oncall-integrations.md"
FLOWS = {"PostgreSQL", "RoomService", "LiveKit/TURN", "Caddy/admission", "OTLP/Tempo", "Attachments", "Realtime/WebSocket"}
REQUIRED = (
    "POC-03: BLOCKED", "Production outage matrix: NOT_RUN", "200 ready", "503 degraded",
    "ADMINISTRATOR", "no-store", "liveness", "не доказывает", "не настроен", "ACL",
)


def validate_document(text):
    errors, found = [], []
    rows = [line for line in text.splitlines() if line.startswith("| ")]
    for row in rows:
        cells = [cell.strip() for cell in row.strip("|").split("|")]
        if cells[0] in FLOWS:
            found.append(cells[0])
            if len(cells) != 8 or any(not cell for cell in cells):
                errors.append("incomplete flow columns: " + cells[0])
            elif not all("[" in cells[index] and "](" in cells[index] for index in (4, 6, 7)):
                errors.append("missing signal/runbook/evidence link: " + cells[0])
            elif "../../backend/" not in row and "../../deploy/" not in row and "../../clients/" not in row:
                errors.append("missing exact source link: " + cells[0])
    if len(found) != len(FLOWS) or set(found) != FLOWS:
        errors.append("expected exactly seven unique integration boundaries")
    for phrase in {*REQUIRED, *(phrase for _, _, phrase in ANCHORS)}:
        if phrase not in text:
            errors.append("missing documented semantic: " + phrase)
    return errors


def validate(root):
    errors = validate_document((root / DOCUMENT).read_text(encoding="utf-8"))
    sources = {}
    for path in {*(path for path, _, _ in ANCHORS), *(path for path, _ in FORBIDDEN)}:
        try:
            sources[path] = (root / path).read_text(encoding="utf-8")
        except FileNotFoundError:
            errors.append("missing source: " + path)
            sources[path] = ""
    errors += ["source drift: " + path for path, anchor, _ in ANCHORS if anchor not in sources[path]]
    errors += ["new timeout/retry/transport configuration: " + path for path, anchor in FORBIDDEN if anchor in sources[path]]
    return errors


def main():
    errors = validate(Path(__file__).resolve().parents[3])
    if errors:
        raise ValueError("\n".join(sorted(set(errors))))
    print("On-call integration map: seven boundaries and source deadlines PASS")


if __name__ == "__main__":
    main()
