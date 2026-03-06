#!/usr/bin/env bash
#
# Adjust default device volume and send a notification with the current level
#
# Requirements:
# - wireplumber (wpctl)
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com> (Updated for wpctl)

DEF_VALUE=1
MIN=0
MAX=100

usage() {
	local script=${0##*/}

	cat >&2 <<- EOF
		USAGE: $script {input|output} {mute|raise|lower} [value]

		Adjust default device volume using wpctl

		DEVICE:
		  input            Use "@DEFAULT_AUDIO_SOURCE@"
		  output           Use "@DEFAULT_AUDIO_SINK@"

		OPTIONS:
		  mute             Toggle device mute
		  raise [value]    Raise volume by [value] (default: $DEF_VALUE)
		  lower [value]    Lower volume by [value] (default: $DEF_VALUE)
	EOF
}

get_volume() {
	wpctl get-volume "$DEV_DEF" | awk '{print $2 * 100}' | cut -d. -f1
}

set_state() {
	wpctl set-mute "$DEV_DEF" toggle
}

set_volume() {
	local level=$(get_volume)
	local step=$VALUE
	
	case $ACTION in
		raise)
			wpctl set-volume -l 1.0 "$DEV_DEF" "$step%+"
			;;
		lower)
			wpctl set-volume "$DEV_DEF" "$step%-"
			;;
	esac
}

main() {
	DEVICE=$1
	ACTION=$2
	VALUE=${3:-$DEF_VALUE}

	case $DEVICE in
		input)  DEV_DEF="@DEFAULT_AUDIO_SOURCE@" ;;
		output) DEV_DEF="@DEFAULT_AUDIO_SINK@" ;;
		*) usage; return 1 ;;
	esac

	case $ACTION in
		mute)          set_state ;;
		raise | lower) set_volume ;;
		*) usage; return 1 ;;
	esac
}

main "$@"

