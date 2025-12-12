#!/usr/bin/env bash

set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "English"
  exit 0
fi

hyprctl -j devices 2>/dev/null | jq -r '(.keyboards[]?.active_keymap // "English")' | head -n1 || echo "English"
