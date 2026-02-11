#!/usr/bin/env bash

# Скрипт для смены обоев и генерации цветов

# Функция для применения тем через matugen
apply_theme() {
    local mode=$1
    local source=$2
    
    # Генерируем CSS для Waybar
    matugen $mode "$source" -t ~/.config/swww/templates/colors.css > ~/.cache/matugen/colors.css
    
    # Генерируем RASI для Rofi
    matugen $mode "$source" -t ~/.config/swww/templates/rofi.rasi > ~/.cache/matugen/rofi.rasi
    
    # Перезагружаем Waybar (если запущен)
    pkill waybar && waybar &
}

if [ "$1" = "init" ]; then
    # Ищем дефолтную картинку. Ты можешь просто положить её в ~/.config/swww/wall.png
    if [ -f ~/.config/swww/wall.png ]; then
        swww img ~/.config/swww/wall.png
        apply_theme "image" ~/.config/swww/wall.png
    fi
    exit 0
fi

if [ "$1" = "pick" ]; then
    color=$(hyprpicker -a)
    apply_theme "color hex" "$color"
else
    if [ -z "$1" ]; then
        echo "Usage: wall.sh [path_to_image | pick]"
        exit 1
    fi
    swww img "$1" --transition-type center
    apply_theme "image" "$1"
fi
