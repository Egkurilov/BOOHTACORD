"""Conservative component selection. Unknown ownership always runs every gate."""
ALL = frozenset({'contracts', 'backend', 'web', 'flutter', 'windows', 'server'})
SERVER = frozenset({'contracts', 'backend', 'web', 'server'})


def select(paths):
    if paths is None:
        return set(ALL)
    selected = {'contracts'}
    for path in paths:
        if path.startswith(('contracts/', '.github/', 'tools/ci/', 'tools/verify/')) or path in (
            'tools/toolchains.json', 'tools/requirements-ci.txt', 'Taskfile.yml',
            'AGENTS.md', 'SKILL.md', 'structure.config.yaml', '.node-version',
        ):
            return set(ALL)
        if path.startswith(('docs/', 'evidence/', 'backlog/')) or path in ('README.md', 'LICENSE', '.gitignore'):
            continue
        if path.startswith('backend/'):
            selected.update(('backend', 'server'))
        elif path.startswith('clients/web/'):
            selected.update(('web', 'server'))
        elif path.startswith('clients/flutter/'):
            selected.update(('flutter', 'windows'))
        elif path.startswith(('deploy/', 'docker/', 'tools/release/', 'tools/build/server/')) or path in ('compose.yaml', '.env.example'):
            selected.update(SERVER)
        elif path.startswith('tools/build/native/'):
            selected.update(('flutter', 'windows'))
        else:
            return set(ALL)
    return selected
