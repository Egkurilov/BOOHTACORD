"""Attempt every owned cleanup independently; leave foreign resources untouched."""
from tools.qa.client_lifecycle.services import remove_owned


def cleanup(stack):
    failed = 0
    try:
        stack.stop_api()
    except Exception:
        failed += 1
    for kind, name in reversed(tuple(stack.resources)):
        try:
            remove_owned(name, stack.owner, kind)
            stack.resources.remove((kind, name))
        except Exception:
            failed += 1
    return dict(owned_resources_removed=not stack.resources and stack.api is None,
                cleanup_failures=failed, remaining_owned_resource_count=len(stack.resources))
