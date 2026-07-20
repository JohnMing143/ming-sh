#!/usr/bin/env python3
"""Reduce a Bash script to a language-neutral code skeleton.

Used by tests_variant_structure_sync.sh to compare the localized ming.sh
implementations against the root script: translated text lives in string
literals, comments, and heredoc bodies, so after blanking those the
remaining line sequence must be identical for every variant.

The scanner is a heuristic, not a Bash parser. It only needs to be
deterministic and equally wrong for every variant: when the same code
surrounds different translated text, the same skeleton must come out.
"""
import re
import sys

HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def blank_strings_and_comment(line: str) -> str:
    """Blank quoted string contents; cut an unquoted trailing comment."""
    out = []
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote is None:
            if ch == "\\" and i + 1 < len(line):
                out.append(line[i : i + 2])
                i += 2
                continue
            if ch in "'\"":
                quote = ch
                out.append(ch)
                i += 1
                continue
            if ch == "#":
                break
            out.append(ch)
            i += 1
            continue
        if quote == '"' and ch == "\\" and i + 1 < len(line):
            i += 2
            continue
        if ch == quote:
            quote = None
            out.append(ch)
            i += 1
            continue
        i += 1
    return "".join(out)


def heredoc_terminators(line: str) -> list[str]:
    """Terminator words for heredocs opened on this line, in order."""
    terminators = []
    for match in HEREDOC_RE.finditer(line):
        start = match.start()
        # Skip herestrings (<<<) and arithmetic shifts inside $(( )).
        if line[start - 1 : start] == "<" or line[match.end() : match.end() + 1] == "<":
            continue
        terminators.append(match.group(2))
    return terminators


def skeleton(path: str) -> list[str]:
    lines = []
    pending: list[str] = []
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if pending:
                if line.lstrip("\t").strip() == pending[0]:
                    pending.pop(0)
                continue
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            pending = heredoc_terminators(line)
            cleaned = blank_strings_and_comment(line).strip()
            if cleaned:
                lines.append(cleaned)
    return lines


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <script.sh>", file=sys.stderr)
        return 2
    for line in skeleton(sys.argv[1]):
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
