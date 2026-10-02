"""Repository document references inside JSON evidence, separate from retained media."""
import re


def references(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from references(child)
    elif isinstance(value, list):
        for child in value:
            yield from references(child)
    elif isinstance(value, str) and value.startswith(('evidence/', 'docs/', 'backlog/', 'contracts/')):
        if ' ' in value or '*' in value or value.startswith('evidence/design/artifacts/'):
            return
        yield re.sub(r':\d+(?:-\d+)?$', '', value).split('#')[0]
