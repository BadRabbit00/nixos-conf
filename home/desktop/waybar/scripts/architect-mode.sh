#!/usr/bin/env bash

# Путь к проекту
PROJECT_DIR="$HOME/project"

# Проверяем, существует ли папка, если нет - создаем
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
fi

# Логируем запуск для отладки
logger "Architect Mode: Script started with args: $@"

# Функция для запуска приложения на конкретном воркспейсе
launch_on_ws() {
    local ws=$1
    local cmd=$2
    logger "Architect Mode: Launching '$cmd' on workspace $ws"
    niri msg action focus-workspace "$ws"
    # Запускаем в фоне
    eval "$cmd" &
    # Даем немного времени приложению проснуться
    sleep 0.3
}

# 1. Workspace 1: Терминалы
launch_on_ws 1 "kitty --directory $PROJECT_DIR"
launch_on_ws 1 "kitty --directory $PROJECT_DIR -e nix shell nixpkgs#gemini-cli"

# 2. Workspace 2: Браузер
BROWSER="google-chrome-stable"
launch_on_ws 2 "$BROWSER"

# 3. Workspace 3: VS Code
launch_on_ws 3 "code $PROJECT_DIR"

# 4. Workspace 4: Мониторинг (btop)
launch_on_ws 4 "kitty -e btop"

# Если передан аргумент --gpu (через Ctrl в бинде), открываем еще и nvidia-smi
if [[ "$1" == "--gpu" ]]; then
    launch_on_ws 4 "kitty -e watch -n 1 nvidia-smi"
fi

# 8. Workspace 8: Telegram
launch_on_ws 8 "telegram-desktop"

# 9. Workspace 9: Spotify
launch_on_ws 9 "spotify"

# Возвращаемся на 1 воркспейс, чтобы начать работу
niri msg action focus-workspace 1
