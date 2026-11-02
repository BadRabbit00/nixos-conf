#!/usr/bin/env bash

# Ручная смена обоев (тема Infernal Blood).
# Автоматическая ротация раз в 5 минут живёт в wall-cycle.

WALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/awww"

case "$1" in
    init)
        # Стартовые обои по умолчанию, мгновенно.
        [ -f "$WALL_DIR/wall.png" ] && awww img "$WALL_DIR/wall.png" --transition-step 255
        ;;
    pick)
        # Случайная картинка из коллекции на все экраны.
        wall="$(find -L "$WALL_DIR/wallpapers" -type f -name '*.png' | shuf -n 1)"
        [ -n "$wall" ] && awww img "$wall" --transition-step 255
        ;;
    "")
        echo "Usage: wall.sh init | pick | <path_to_image>" >&2
        exit 1
        ;;
    *)
        awww img "$1" --transition-step 255
        ;;
esac
