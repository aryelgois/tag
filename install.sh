#!/usr/bin/env bash

# setup paths
ROOT="${1:-/usr/local}"
BINPATH="$ROOT/bin"
MANPATH="$ROOT/man/man1"
mkdir -p "$BINPATH" "$MANPATH"

# install script
install -m 0755 src/tag.sh "$BINPATH/tag"

# install man page
install -m 0644 doc/tag.1 "$MANPATH/" && gzip "$MANPATH/tag.1" -f
