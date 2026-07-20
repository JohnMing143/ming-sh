#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Inline the canonical shared shell library into its consumers.

Shipped scripts must stay self-contained, so shared helpers are not sourced
at runtime; they are embedded between generation markers. Edit the library
under lib/ and run this tool to refresh every consumer:

    python3 lib/inline.py          # rewrite consumers
    python3 lib/inline.py --check  # verify only (used by the test suite)

The main entrypoint is a consumer too: after inlining changes ming.sh, run
`python3 translate.py generate --all` to refresh the localized variants.
"""
import os
import sys

LIBS = {
    'remote_script': {
        'source': 'remote_script.sh',
        'consumers': ['ming.sh', 'mc.sh', 'palworld.sh', 'hermes_manager.sh'],
    },
}

BEGIN = '# --- ming-sh shared lib: {name} (generated from lib/{source}; edit there, then run: python3 lib/inline.py) ---'
END = '# --- end ming-sh shared lib: {name} ---'


def repo_path(*parts):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', *parts)


def library_body(source):
    """The library content minus its leading comment header."""
    with open(repo_path('lib', source), encoding='utf-8') as handle:
        lines = handle.read().splitlines()
    start = 0
    for index, line in enumerate(lines):
        if line.strip() and not line.lstrip().startswith('#'):
            start = index
            break
    return '\n'.join(lines[start:]).strip('\n')


def process(name, spec, check_only):
    begin = BEGIN.format(name=name, source=spec['source'])
    end = END.format(name=name)
    block = f'{begin}\n{library_body(spec["source"])}\n{end}'
    dirty = []
    for consumer in spec['consumers']:
        path = repo_path(consumer)
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
        if begin not in text or end not in text:
            print(f'{consumer}: missing {name} markers', file=sys.stderr)
            dirty.append(consumer)
            continue
        head, rest = text.split(begin, 1)
        _, tail = rest.split(end, 1)
        updated = head + block + tail
        if updated == text:
            continue
        if check_only:
            print(f'{consumer}: inlined {name} copy is stale', file=sys.stderr)
            dirty.append(consumer)
        else:
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(updated)
            print(f'{consumer}: refreshed {name}')
    return dirty


def main():
    check_only = '--check' in sys.argv[1:]
    dirty = []
    for name, spec in LIBS.items():
        dirty.extend(process(name, spec, check_only))
    if dirty:
        print('run: python3 lib/inline.py (and translate.py generate --all if ming.sh changed)', file=sys.stderr)
        return 1
    if check_only:
        print('shared library copies are in sync')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
