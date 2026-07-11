#!/usr/bin/env sh
set -eu

destination="${1:-.}"
output="$destination/GODOT_COPYRIGHT.txt"
temporary="$output.tmp"
expected="cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d"
url="https://raw.githubusercontent.com/godotengine/godot/4.7-stable/COPYRIGHT.txt"

curl -L --fail --retry 3 -o "$temporary" "$url"
printf '%s  %s\n' "$expected" "$temporary" | shasum -a 256 -c -
mv "$temporary" "$output"
