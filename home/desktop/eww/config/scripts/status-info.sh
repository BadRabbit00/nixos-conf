#!/usr/bin/env bash

# Keep this file executable so eww can poll Wi-Fi status.

set -euo pipefail

fallback_icon="󰤭"

if ! command -v nmcli >/dev/null 2>&1; then
  case "$1" in
    wifi-icon) echo "$fallback_icon" ;;
    wifi-label) echo "Wi-Fi unavailable" ;;
  esac
  exit 0
fi

case "${1:-}" in
  wifi-label)
    info="$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2\";\"$3; exit}' || true)"
    if [ -z "${info:-}" ]; then
      echo "Offline"
      exit 0
    fi
    ssid="${info%;*}"
    signal="${info#*;}"
    [ -z "$ssid" ] && ssid="Unknown"
    [ -z "$signal" ] && signal=0
    echo "${ssid} • ${signal}%"
    ;;
  wifi-icon)
    signal="$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}' || true)"
    [ -z "${signal:-}" ] && signal=0
    if [ "${signal%.*}" -ge 80 ]; then
      icon="󰤨"
    elif [ "${signal%.*}" -ge 60 ]; then
      icon="󰤥"
    elif [ "${signal%.*}" -ge 40 ]; then
      icon="󰤢"
    elif [ "${signal%.*}" -ge 20 ]; then
      icon="󰤟"
    else
      icon="󰤯"
    fi
    echo "$icon"
    ;;
  *)
    exit 0
    ;;
esac
