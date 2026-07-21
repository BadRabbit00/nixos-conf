#!/usr/bin/env bash

# Путь к файлу с фразами
PHRASES_FILE="$HOME/.config/niri/scripts/phrases.txt"

# Если файла нет, возвращаем дефолт
if [ ! -f "$PHRASES_FILE" ]; then
    echo "Identify yourself..."
    exit 0
fi

# Читаем рандомную строку
shuf -n 1 "$PHRASES_FILE"
