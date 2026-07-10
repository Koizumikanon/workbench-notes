#!/usr/bin/env bash
set -euo pipefail

target_dir="${1:-docs}"
denylist_file="${2:-}"

if [[ ! -d "$target_dir" ]]; then
  printf 'Public docs directory not found: %s\n' "$target_dir" >&2
  exit 2
fi

patterns=(
  '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
  'ssh-(rsa|ed25519|ecdsa) AAAA'
  'AKIA[0-9A-Z]{16}'
  '(api[_-]?key|access[_-]?key|secret[_-]?key|token|password)[[:space:]]*[:=][[:space:]]*[^ <]+'
  '\b10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b'
  '\b192\.168\.[0-9]{1,3}\.[0-9]{1,3}\b'
  '\b172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}\b'
)

failed=0
for pattern in "${patterns[@]}"; do
  if rg -n -i -e "$pattern" "$target_dir"; then
    failed=1
  fi
done

if [[ -n "$denylist_file" ]]; then
  if [[ ! -f "$denylist_file" ]]; then
    printf 'Private denylist not found: %s\n' "$denylist_file" >&2
    exit 2
  fi
  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    if rg -n -i -e "$pattern" "$target_dir"; then
      failed=1
    fi
  done < "$denylist_file"
fi

if (( failed )); then
  printf 'Public documentation audit failed. Remove or replace the matched content.\n' >&2
  exit 1
fi

printf 'Public documentation audit passed: %s\n' "$target_dir"
