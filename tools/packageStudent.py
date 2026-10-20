#!/usr/bin/env python3
"""Build the standalone MATLAB source ZIP from one committed main revision.

No working-tree, private-note, Git-history or school-toolbox files are read into
this archive. Tests and generators accompany the app as editable source.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = {'src', 'resources', 'docs', 'examples', 'licenses', 'tests', 'tools', '.github'}
FILES = {'README.md', 'LICENSE.txt', 'OWNERS.txt', 'setupColorMeasure.m',
         'demoDirectInstruments.m', 'testLabInstrument.m'}
PREFIX = 'ColorMeasurement-MATLAB/'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def build(commit, output):
    commit = git('rev-parse', '--verify', commit + '^{commit}').decode().strip()
    git('merge-base', '--is-ancestor', commit, 'main')
    tree = git('rev-parse', commit + '^{tree}').decode().strip()
    source = tarfile.open(fileobj=io.BytesIO(git('archive', '--format=tar', commit)))
    payload = {}
    for member in source:
        name = member.name
        if not member.isfile():
            if member.isdir():
                continue
            raise ValueError(f'Unsupported source entry: {name}')
        if name in FILES or name.split('/')[0] in FOLDERS:
            payload[name] = source.extractfile(member).read()
        elif name not in {'.gitignore', '.gitattributes'}:
            raise ValueError(f'Unclassified tracked file: {name}')
    missing = FILES - payload.keys()
    if missing:
        raise ValueError(f'Missing package entrypoints/notices: {sorted(missing)}')
    if any(name.startswith('src/+colormeasure/+argyll/') for name in payload):
        raise ValueError('Standalone package must use direct-only main, not the Argyll product.')
    manifest = {'schemaVersion': 1, 'sourceCommit': commit, 'sourceTree': tree,
                'files': {name: hashlib.sha256(data).hexdigest()
                          for name, data in sorted(payload.items())}}
    payload['package-manifest.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation prevents overwriting a previously published artifact.
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(payload.items()):
            entry = zipfile.ZipInfo(PREFIX + name, (2026, 1, 1, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    print(json.dumps({'archive': str(output), 'sha256': digest,
                      'sourceCommit': commit, 'sourceTree': tree,
                      'files': len(payload)}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', default='main')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    build(args.commit, args.output)
