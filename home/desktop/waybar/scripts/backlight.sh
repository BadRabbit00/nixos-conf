#!/usr/bin/env bash
#
# Adjust screen brightness and send a notification with the current level
#
# Requirements:
# - brightnessctl (laptop panel, eDP-*)
# - ddcutil, niri, jq, flock (external monitors via DDC/CI, VCP 0x10)
# - notify-send (libnotify)
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 28, 2025
# License: MIT

DEF_VALUE=1

usage() {
	local script=${0##*/}

	cat >&2 <<- EOF
		USAGE: $script {up|down} [value]

		Adjust brightness of the focused output (eDP-* via brightnessctl,
		external monitors via DDC/CI)

		OPTIONS:
		  up   [value]    Increase brightness by [value] (default: $DEF_VALUE)
		  down [value]    Decrease brightness by [value] (default: $DEF_VALUE)

		EXAMPLES:
		  Increase brightness:
		    $ $script up

		  Decrease brightness by 5:
		    $ $script down 5
	EOF
}

# Brightness of an external monitor over DDC/CI. Monitor is picked by the serial
# number reported by niri (bus numbers change between boots).
ddc_set() {
	local sign=$1
	local value=$2
	local serial=$3
	local lock=${XDG_RUNTIME_DIR:-/tmp}/backlight-ddc.lock

	# DDC is slow (~100 ms+): skip the key repeat instead of queueing calls
	if ! command -v ddcutil > /dev/null; then
		notify-send "Brightness" "ddcutil not installed"
		return 1
	fi

	exec 9> "$lock" || return 1
	flock -n 9 || return 0

	if ! ddcutil --sn "$serial" --noverify --sleep-multiplier .1 \
		setvcp 10 "$sign" "$value" > /dev/null 2>&1; then
		notify-send -u critical "Brightness" "DDC/CI failed for monitor $serial (i2c group? i2c-dev?)" 9>&-
		return 1
	fi
}

main() {
	local action=$1
	local value=${2:-$DEF_VALUE}

	if ((value < 1)); then
		usage
		return 1
	fi

	case $action in
	up | down) ;;
	*)
		usage
		return 1
		;;
	esac

	local sign
	case $action in
	up) sign='+' ;;
	down) sign='-' ;;
	esac

	# Focused output follows the mouse; external monitors have no backlight class
	local name="" serial="" info
	if info=$(niri msg -j focused-output 2> /dev/null); then
		IFS=$'\t' read -r name serial < <(jq -r '[.name // "", .serial // ""] | @tsv' <<< "$info") || true
	fi

	if [[ -n $name && $name != eDP-* ]]; then
		if [[ -z $serial ]]; then
			notify-send -u critical "Brightness" "No serial for output $name, DDC unavailable"
			return 1
		fi
		ddc_set "$sign" "$value" "$serial"
		return
	fi

	local device=""

	# Use intel_backlight if it exists (confirmed to work)
	if [[ -d /sys/class/backlight/intel_backlight ]]; then
		device="-d intel_backlight"
	elif [[ -d /sys/class/backlight/nvidia_0 ]]; then
		device="-d nvidia_0"
	fi

	# shellcheck disable=SC2086
	brightnessctl $device -n set "${value}%${sign}" > /dev/null
}

main "$@"
