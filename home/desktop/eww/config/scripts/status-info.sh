#!/usr/bin/env bash

# Keep this file executable so eww can poll Wi-Fi status.

set -euo pipefail

fallback_icon="󰤭"

if ! command -v nmcli >/dev/null 2>&1; then
  case "$1" in
    wifi-icon) echo "$fallback_icon" ;;
    wifi-label) echo "Wi-Fi unavailable" ;;
    *) exit 0 ;;
  esac
  exit 0
fi

case "${1:-}" in
  wifi-label)
    info="$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2";"$3; exit}' || true)"
    if [ -z "${info:-}" ]; then
      echo "Offline"
      exit 0
    fi
    ssid="${info%;*}"
    signal="${info#*;}"
    [ -z "$ssid" ] && ssid="Unknown"
    signal="${signal:-0}"
    case "$signal" in
      ''|*[!0-9]*) signal=0 ;;
    esac
    [ "$signal" -lt 0 ] && signal=0
    [ "$signal" -gt 100 ] && signal=100
    echo "${ssid} • ${signal}%"
    ;;
  wifi-icon)
    signal="$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}' || true)"
    signal="${signal:-0}"
    signal_int="${signal%%.*}"
    case "$signal_int" in
      ''|*[!0-9]*) signal_int=0 ;;
    esac
    [ "$signal_int" -lt 0 ] && signal_int=0
    [ "$signal_int" -gt 100 ] && signal_int=100
    if [ "$signal_int" -eq 0 ]; then
      icon="$fallback_icon"
    elif [ "$signal_int" -ge 80 ]; then
      icon="󰤨"
    elif [ "$signal_int" -ge 60 ]; then
      icon="󰤥"
    elif [ "$signal_int" -ge 40 ]; then
      icon="󰤢"
    elif [ "$signal_int" -ge 20 ]; then
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
