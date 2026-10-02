"""Compare resolved deployment models, allowing only declared relocation/build changes."""
import copy


def production_model(model):
    model = copy.deepcopy(model)
    for name in list(model):
        if name.startswith('x-'): model.pop(name)
    for service in model['services'].values():
        service.pop('build', None)
        for mount in service.get('volumes', []):
            if mount['type'] == 'bind':
                source = mount['source'].replace('\\', '/')
                for old, new in (('/docker/Caddyfile', '/deploy/caddy/Caddyfile'),
                                 ('/docker/livekit.yaml', '/deploy/livekit/livekit.yaml')):
                    if source.endswith(old): source = source[:-len(old)] + new
                mount['source'] = source
    return model


def compare(before, after):
    if any('build' in service for service in after['services'].values()):
        raise ValueError('Production deployment must not contain build instructions')
    if production_model(before) != production_model(after):
        raise ValueError('Deployment behavior differs beyond approved paths/build policy')
