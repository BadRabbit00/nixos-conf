#!/usr/bin/env bash

# Скрипт для смены обоев (Статичная тема Infernal Blood)

if [ "$1" = "init" ]; then
    if [ -f ~/.config/swww/wall.png ]; then
        swww img ~/.config/swww/wall.png --transition-step 255 # Мгновенно
    fi
    exit 0
fi

if [ -z "$1" ]; then
    echo "Usage: wall.sh [path_to_image]"
    exit 1
fi

swww img "$1" --transition-type center
