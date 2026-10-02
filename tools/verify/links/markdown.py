"""Local Markdown link targets, including reference-style links."""
import re
from urllib.parse import unquote, urlsplit


def targets(source):
    source = re.sub(r'(?ms)^\s*(`{3,}|~{3,}).*?^\s*\1\s*$', '', source)
    inline = re.findall(r'!?\[[^\n]*?\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[\'\"].*?[\'\"])?\s*\)', source)
    references = re.findall(r'(?m)^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)', source)
    for value in inline + references:
        value = value.strip('<>')
        uri = urlsplit(value)
        if uri.scheme or uri.netloc or not uri.path:
            continue
        yield unquote(uri.path)
