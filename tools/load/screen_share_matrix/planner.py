"""Compile versioned media-load scenarios without connecting to any service."""
import argparse
import json
from pathlib import Path


CATALOG = Path(__file__).with_name('profiles-v1.json')


def load_catalog():
    return json.loads(CATALOG.read_text(encoding='utf-8'))


def _room(index, spec, max_streams, pattern, hot_audience):
    members = [f'R{index}-U{n:02}' for n in range(1, spec['participants'] + 1)]
    publishers = members[:spec['publishers']]
    if not publishers or len(publishers) > len(members):
        raise ValueError('room publisher count must be between 1 and room size')
    edges = []
    for number, viewer in enumerate(members):
        if pattern == 'hot' and number < hot_audience:
            selected = [publishers[0] if publishers[0] != viewer else publishers[1]]
        elif pattern == 'ring' and len(publishers) == len(members):
            selected = [publishers[(number + 1) % len(publishers)]]
        else:
            available = [p for p in publishers if p != viewer]
            start = number % len(available) if available else 0
            selected = [available[(start + n) % len(available)] for n in range(min(max_streams, len(available)))]
        edges.extend((viewer, source) for source in selected if source != viewer)
    return {'members': members, 'publishers': publishers, 'subscriptions': edges}


def plan_profile(catalog, profile_id):
    profile = next((p for p in catalog['profiles'] if p['id'] == profile_id), None)
    if profile is None:
        raise ValueError(f'unknown profile: {profile_id}')
    if profile['participants'] > 30 or any(r['participants'] > 20 for r in profile['rooms']):
        raise ValueError('profile exceeds the declared 30-participant / 20-per-room envelope')
    rooms = [_room(i, room, profile['subscriptions_per_viewer'], profile['subscription_pattern'],
                   profile.get('hot_audience_per_room', 0)) for i, room in enumerate(profile['rooms'], 1)]
    if sum(len(r['members']) for r in rooms) != profile['participants']:
        raise ValueError('room membership does not equal profile participant count')
    edges = [edge for room in rooms for edge in room['subscriptions']]
    counts = {}
    for viewer, _ in edges:
        counts[viewer] = counts.get(viewer, 0) + 1
    if any(count > profile['subscriptions_per_viewer'] for count in counts.values()):
        raise ValueError('subscription fan-out exceeds profile budget')
    return {'schema_version': catalog['schema_version'], 'profile': profile, 'rooms': rooms,
            'participants': profile['participants'], 'publishers': sum(len(r['publishers']) for r in rooms),
            'subscriptions': edges, 'max_subscriptions_per_viewer': max(counts.values(), default=0),
            'phases_seconds': catalog['phases_seconds'], 'repeats': catalog['repeats'] if profile_id in catalog['repeat_profiles'] else 1,
            'evidence': {'generator': 'NOT_RUN', 'sfu': 'NOT_RUN', 'physical_decode': 'NOT_RUN', 'voice': 'NOT_RUN'},
            'outcome': 'NOT_RUN', 'limitation': 'topology plan only; no media clients, RTP, codec, SFU capacity, or device decode executed'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', required=True, choices=[p['id'] for p in load_catalog()['profiles']])
    args = parser.parse_args()
    print(json.dumps(plan_profile(load_catalog(), args.profile), indent=2))


if __name__ == '__main__':
    main()
