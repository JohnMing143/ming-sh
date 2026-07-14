#!/usr/bin/env bash
# Legacy local entrypoint retained for compatibility. It never downloads code.

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
target="${script_dir}/ming.sh"

if [ ! -r "$target" ]; then
	echo "Legacy entrypoint could not find ${target}." >&2
	echo "Run ming.sh from the same repository checkout instead." >&2
	exit 1
fi

exec bash "$target" "$@"
