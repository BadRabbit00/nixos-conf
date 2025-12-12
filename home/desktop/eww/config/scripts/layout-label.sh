#!/usr/bin/env bash

set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "English"
  exit 0
fi

hyprctl -j devices 2>/dev/null | jq -r '([.keyboards[]?.active_keymap // empty] | map(select(length > 0)) | .[0]) // "English"' || echo "English"
