#!/usr/bin/env bash
#
# Adjust screen brightness and send a notification with the current level
#
# Requirements:
# - brightnessctl
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

		Adjust screen brightness and send a notification with the current level

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

main() {
	local action=$1
	local value=${2:-$DEF_VALUE}

	if ((value < 1)); then
		usage
		return 1
	fi

	case $action in
	        up | down)
	                local sign
	                local device=""

	                # Use intel_backlight if it exists (confirmed to work)
	                if [[ -d /sys/class/backlight/intel_backlight ]]; then
	                    device="-d intel_backlight"
	                elif [[ -d /sys/class/backlight/nvidia_0 ]]; then
	                    device="-d nvidia_0"
	                fi

	                case $action in
	                        up)   sign='+' ;;
	                        down) sign='-' ;;
	                esac

	                brightnessctl $device -n set "${value}%${sign}" > /dev/null
	                ;;			
		*)
			usage
			return 1
			;;
	esac
}

main "$@"
