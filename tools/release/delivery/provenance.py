"""Accept artifacts only from this repository's successful protected server build."""
import json
import os
import re
from urllib.request import Request, urlopen


def validate(run, repository, revision=None):
    source = run.get('head_sha', '')
    if not re.fullmatch(r'[0-9a-f]{40}', source): raise ValueError('Invalid build source revision')
    if revision is not None and revision != source: raise ValueError('Requested revision differs from build')
    if run.get('head_repository', {}).get('full_name') != repository: raise ValueError('Foreign build repository')
    if run.get('path') != '.github/workflows/build-server.yaml': raise ValueError('Unexpected producer workflow')
    if run.get('head_branch') != 'master' or run.get('event') not in ('push', 'workflow_dispatch'):
        raise ValueError('Build did not originate from master')
    if run.get('conclusion') != 'success' or run.get('status') != 'completed': raise ValueError('Build is incomplete')
    return source


def main():
    repository = os.environ['GITHUB_REPOSITORY']
    run_id = os.environ['BUILD_RUN_ID']
    if not re.fullmatch(r'[0-9]+', run_id): raise ValueError('Numeric build run ID is required')
    request = Request(f'https://api.github.com/repos/{repository}/actions/runs/{run_id}', headers={
        'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'], 'Accept': 'application/vnd.github+json'})
    with urlopen(request, timeout=30) as response: run = json.load(response)
    revision = validate(run, repository, os.environ.get('REQUESTED_REVISION') or None)
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        stream.write(f'revision={revision}\nrun_id={run_id}\n')
    print('Verified successful master build ' + run_id + ' at ' + revision)


if __name__ == '__main__': main()
