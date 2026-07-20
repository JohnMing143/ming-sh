#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Localization pipeline for the ming.sh entrypoint variants.

The root ming.sh is the single canonical implementation. Every localized
variant is generated from it:

- cn/ming.sh is the root with only the canshu variant marker changed.
- en|jp|kr|tw/ming.sh are the root with translated lines substituted from a
  per-language catalog (<lang>/catalog.json). The catalog maps an exact root
  line to its translated form; lines without an entry pass through unchanged.

Offline subcommands (never touch the network):
  harvest   --lang LANG|--all  rebuild catalogs from the committed variants
  generate  --lang LANG|--all  regenerate variant files from root + catalogs
  check     --lang LANG|--all  verify committed variants match regeneration
  status    --lang LANG|--all  report root lines that stay untranslated

Remote subcommand (privacy-gated, off by default):
  translate-missing --lang LANG  translate uncataloged Chinese lines with
                                 Google Translate and add them to the catalog.
                                 Requires ALLOW_REMOTE_TRANSLATION=true and
                                 sends source-text fragments to a third party.
"""
import argparse
import json
import os
import re
import sys

REMOTE_TRANSLATION_ENV = 'ALLOW_REMOTE_TRANSLATION'
ROOT_SCRIPT = 'ming.sh'
ROOT_MARKER = 'canshu="default"'
CN_MARKER = 'canshu="CN"'
CATALOG_LANGS = ['en', 'jp', 'kr', 'tw']
ALL_LANGS = ['cn'] + CATALOG_LANGS
GOOGLE_TARGETS = {'en': 'en', 'jp': 'ja', 'kr': 'ko', 'tw': 'zh-TW'}


def require_remote_translation_opt_in():
    if os.environ.get(REMOTE_TRANSLATION_ENV, '').lower() == 'true':
        return
    print(
        'Remote translation sends source text to Google Translate and is disabled by default.',
        file=sys.stderr,
    )
    print(
        f'Review the source, then set {REMOTE_TRANSLATION_ENV}=true to continue.',
        file=sys.stderr,
    )
    raise SystemExit(2)


def is_chinese(text):
    return bool(re.search(r'[一-鿿]', text))


def repo_path(*parts):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), *parts)


def read_lines(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read().splitlines(keepends=True)


def catalog_path(lang):
    return repo_path(lang, 'catalog.json')


def load_catalog(lang):
    path = catalog_path(lang)
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def save_catalog(lang, catalog):
    with open(catalog_path(lang), 'w', encoding='utf-8') as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=0, sort_keys=True)
        handle.write('\n')


def generate_lines(root_lines, lang, catalog=None):
    """Produce the variant's lines from root lines plus the catalog."""
    if lang == 'cn':
        return [
            line.replace(ROOT_MARKER, CN_MARKER)
            if line.rstrip('\n') == ROOT_MARKER else line
            for line in root_lines
        ]
    if catalog is None:
        catalog = load_catalog(lang)
    seen = {}
    out = []
    for line in root_lines:
        key = line.rstrip('\n')
        entry = catalog.get(key)
        if entry is None:
            out.append(line)
            continue
        index = seen.get(key, 0)
        seen[key] = index + 1
        translated = entry[min(index, len(entry) - 1)]
        newline = '\n' if line.endswith('\n') else ''
        out.append(translated + newline)
    return out


def harvest(lang):
    """Rebuild the catalog from the committed 1:1 aligned variant."""
    root_lines = read_lines(repo_path(ROOT_SCRIPT))
    variant_lines = read_lines(repo_path(lang, 'ming.sh'))
    if len(root_lines) != len(variant_lines):
        print(
            f'{lang}: variant is not 1:1 aligned with the root script '
            f'({len(variant_lines)} vs {len(root_lines)} lines); align it first.',
            file=sys.stderr,
        )
        return 1
    pairs = {}
    dropped = 0
    for root_line, variant_line in zip(root_lines, variant_lines):
        root_key = root_line.rstrip('\n')
        variant_value = variant_line.rstrip('\n')
        if root_key == variant_value:
            continue
        # Only lines carrying Chinese text are translatable; a variant that
        # deviates on a pure code line is drift and must follow the root.
        if not is_chinese(root_key):
            dropped += 1
            continue
        pairs.setdefault(root_key, []).append(variant_value)
    catalog = {}
    for key, values in pairs.items():
        if len(set(values)) == 1:
            catalog[key] = [values[0]]
        else:
            catalog[key] = values
    save_catalog(lang, catalog)
    note = f' ({dropped} non-Chinese deviations left for generate to normalize)' if dropped else ''
    print(f'{lang}: harvested {len(catalog)} catalog entries{note}')
    return 0


def generate(lang):
    root_lines = read_lines(repo_path(ROOT_SCRIPT))
    out = generate_lines(root_lines, lang)
    with open(repo_path(lang, 'ming.sh'), 'w', encoding='utf-8') as handle:
        handle.writelines(out)
    print(f'{lang}: regenerated {lang}/ming.sh')
    return 0


def check(lang):
    root_lines = read_lines(repo_path(ROOT_SCRIPT))
    expected = generate_lines(root_lines, lang)
    actual = read_lines(repo_path(lang, 'ming.sh'))
    if expected == actual:
        print(f'{lang}: OK')
        return 0
    limit = 5
    shown = 0
    for number, (want, have) in enumerate(zip(expected, actual), start=1):
        if want != have and shown < limit:
            print(f'{lang}: line {number} differs', file=sys.stderr)
            print(f'  generated: {want.rstrip()!r}', file=sys.stderr)
            print(f'  committed: {have.rstrip()!r}', file=sys.stderr)
            shown += 1
    if len(expected) != len(actual):
        print(
            f'{lang}: line count differs (generated {len(expected)}, '
            f'committed {len(actual)})',
            file=sys.stderr,
        )
    print(
        f'{lang}: committed variant does not match regeneration; '
        f'edit the root script and/or catalog, then run: '
        f'python3 translate.py generate --lang {lang}',
        file=sys.stderr,
    )
    return 1


def status(lang):
    if lang == 'cn':
        print('cn: generated from the root script; no catalog')
        return 0
    root_lines = read_lines(repo_path(ROOT_SCRIPT))
    catalog = load_catalog(lang)
    missing = []
    for number, line in enumerate(root_lines, start=1):
        key = line.rstrip('\n')
        if is_chinese(key) and key not in catalog:
            missing.append((number, key))
    print(f'{lang}: {len(catalog)} catalog entries, {len(missing)} untranslated Chinese lines')
    for number, key in missing[:20]:
        print(f'  line {number}: {key.strip()[:80]}')
    if len(missing) > 20:
        print(f'  ... and {len(missing) - 20} more')
    return 0


def translate_missing(lang):
    """Translate uncataloged Chinese root lines remotely. Privacy-gated."""
    require_remote_translation_opt_in()
    from deep_translator import GoogleTranslator

    translator = GoogleTranslator(source='zh-CN', target=GOOGLE_TARGETS[lang])
    root_lines = read_lines(repo_path(ROOT_SCRIPT))
    catalog = load_catalog(lang)
    added = 0
    for line in root_lines:
        key = line.rstrip('\n')
        if not is_chinese(key) or key in catalog:
            continue
        # Translate quoted contents and comment text, never variables.
        parts = re.split(r'(\$\{\w+\}|\$\w+)', key)
        translated_parts = []
        for part in parts:
            if part.startswith('$') or not is_chinese(part):
                translated_parts.append(part)
                continue
            try:
                translated_parts.append(translator.translate(part))
            except Exception as error:  # noqa: BLE001 - report and keep source
                print(f'[error] {error}', file=sys.stderr)
                translated_parts.append(part)
        catalog[key] = [''.join(translated_parts)]
        added += 1
        print(f'{lang}: +{added}', end='\r')
    save_catalog(lang, catalog)
    print(f'{lang}: added {added} entries; review the catalog diff before committing')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('harvest', 'generate', 'check', 'status'):
        cmd = sub.add_parser(name)
        group = cmd.add_mutually_exclusive_group(required=True)
        group.add_argument('--lang', choices=ALL_LANGS if name != 'harvest' else CATALOG_LANGS)
        group.add_argument('--all', action='store_true')
    remote = sub.add_parser('translate-missing')
    remote.add_argument('--lang', choices=CATALOG_LANGS, required=True)

    args = parser.parse_args()
    actions = {
        'harvest': (harvest, CATALOG_LANGS),
        'generate': (generate, ALL_LANGS),
        'check': (check, ALL_LANGS),
        'status': (status, ALL_LANGS),
    }
    if args.command == 'translate-missing':
        return translate_missing(args.lang)
    action, all_langs = actions[args.command]
    langs = all_langs if args.all else [args.lang]
    exit_status = 0
    for lang in langs:
        exit_status = max(exit_status, action(lang))
    return exit_status


if __name__ == '__main__':
    raise SystemExit(main())
