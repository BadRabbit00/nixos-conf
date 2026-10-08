# 🩸 NixOS "Infernal Mecha" Configuration

This repository contains a modular NixOS configuration managed with **Flakes** and **Home Manager**, themed with a deep, infernal palette and a mecha-inspired interface. It is optimized for a high-performance, keyboard-centric workflow.

## 🎨 Aesthetic Profile

*   **Theme**: Infernal Blood (Static Palette).
*   **Colors**: 
    *   Accent: `#d33637` (Bright Red)
    *   Background: `#0c0c0c` (Deep Void)
    *   Foreground: `#ac7e7c` (Dusty Rose)
    *   Armor Layers: `#351212`, `#403736`, `#242424`
*   **UI Style**: Modular, mechanical, aggressive, and cohesive across all applications.

## 🚀 Key Components

*   **WM**: [Niri](https://github.com/YaLTeR/niri) (Wayland) - A scrollable tiling compositor with a unique horizontal workflow and "Infernal Blood" styling.
*   **Bar**: [Mechabar](https://github.com/sejjy/mechabar) (Waybar) - Fully integrated with custom scripts and the Blood-Red palette. 
    *   *Original credits to [Jesse Mirabel](https://github.com/sejjy) for the mecha-themed base.*
*   **Launcher**: [Rofi](https://github.com/davatorium/rofi) with a custom static Blood-Red theme.
*   **Terminal**: [Kitty](https://sw.kovidgoyal.net/kitty/) - Enhanced with Kittens (hints, icat), ligatures (`CommitMono Nerd Font`), and shell integration.
*   **Lockscreen**: [Hyprlock](https://github.com/hyprwm/hyprlock) - Visual masterpiece with blurred wallpaper, large red clock, and elegant input fields.
*   **System Monitor**: [Btop](https://github.com/aristocratos/btop) with a custom "Infernal Blood" theme.
*   **System Info**: [Fastfetch](https://github.com/fastfetch-cli/fastfetch) configured with custom modules and image support (`logo.png`).

## ⌨️ "Arrow-Mecha" Navigation

The system uses `SUPER` (Win) as the main modifier with standard arrow keys:
*   **Focus**: `Win + Left/Right` (Columns), `Win + Up/Down` (Windows).
*   **Window Resizing**: `Ctrl + Alt + Arrows`
*   **Quick Apps**: `Win + Enter` (Kitty), `Win + B` (Browser), `Win + S` (Spotify), `Win + Q` (Close).
*   **Screenshot**: `Win + Shift + S` (Area selection to clipboard).
*   **Layout Toggle**: `Win + Space`.

## 🛠️ Integrated Scripts (Mechabar)

*   **Network/Bluetooth**: `fzf`-based selection menus inside Kitty.
*   **Power Menu**: Compact session control via `fzf`.
*   **Media/Brightness**: Integrated OSD notifications via `volume.sh` and `backlight.sh`.

## ⚙️ Initial Setup

1.  Clone the repo:
    ```bash
    git clone https://github.com/BadRabbit00/nixos-conf.git && cd nixos-conf
    ```
2.  Set your username/hostname:
    ```bash
    ./setup.sh
    ```
3.  Add your custom logo for fastfetch:
    Place your image at `home/programs/logo.png`.
4.  Apply configuration:
    ```bash
    sudo nixos-rebuild switch --flake .#badrabbitpc
    ```

## Arch Linux (standalone Home Manager)

Один каталог `home/` используется двумя выходами:

| Выход | Пользователь / home | Режим |
| --- | --- | --- |
| `nixosConfigurations.badrabbitpc` | `BadRabbit`, `/home/BadRabbit` | HM внутри NixOS, `isNixOS = true` |
| `homeConfigurations."badrabbit@ARCH-BOX"` | `badrabbit`, `/home/badrabbit` | standalone HM, `isNixOS = false` |

Различия идут через `isNixOS` и standalone-обёртку во флейке. На Arch **не запускайте
корневой `setup.sh`**: он переименовывает NixOS-конфиг. Системные NixOS-модули,
драйверы и специализации на Arch не импортируются.

### Первая установка и обновления

Нужны работающий Arch x86_64 с GDM/GNOME, существующий `badrabbit` с home
`/home/badrabbit`, hostname `ARCH-BOX`, Nix daemon и `nix-command flakes`.
`nvidia-open` в скрипте рассчитан на стандартное ядро Arch `linux`.

Из клона репозитория, принадлежащего `badrabbit`:

```sh
sudo ./arch/setup-system.sh
# Если обновились ядро/NVIDIA: сначала перезагрузитесь, затем продолжите.
nix run --inputs-from . home-manager -- switch --impure --flake .#badrabbit@ARCH-BOX -b backup
```

После Home Manager **никаких sudo-команд не требуется**. Выйдите из сессии и войдите
снова. GDM выберет niri для `badrabbit`; остальные пользователи сохранят GNOME или
свой ранее выбранный сеанс. Автологин GDM не включается. Блокировка внутри niri —
системный hyprlock, запускаемый через hypridle (300 секунд) или `Mod+L`.

Дальнейшие обновления:

```sh
home-manager switch --impure --flake .#badrabbit@ARCH-BOX
```

При совпадении `$USER@$(hostname)` с именем выхода можно опустить `#badrabbit@ARCH-BOX`.
После обновления NVIDIA через pacman порядок обязателен:

```sh
# Сначала перезагрузка, чтобы загрузился новый модуль ядра, затем:
home-manager switch --impure --flake .#badrabbit@ARCH-BOX
```

Собирать Arch-окружение нужно на целевой NVIDIA-машине: GPU-обёртка определяется
по **загруженному модулю**, а не по версии пакета в pacman. Копирование готовой
generation с компьютера с другой версией драйвера для установки не подходит.

### GPU через nixGL

Все пользовательские программы остаются из Nix. Общий хелпер `gpuWrap` вызывает
`config.lib.nixGL.wrap` только на Arch и возвращает исходный пакет на NixOS.
Используется штатная интеграция HM `targets.genericLinux.nixGL`, wrapper `nvidia`,
с поддержкой OpenGL/EGL и Vulkan. Обёртка задаёт пути библиотек и NVIDIA JSON только
в окружении запускаемого процесса и его потомков. Глобальные переменные GPU,
файлы драйвера в системных каталогах и системные службы для этого не создаются.

Обёрнутые программы:

| Пакеты | Причина |
| --- | --- |
| kitty | OpenGL-рендер терминала |
| firefox, google-chrome | GPU-композитинг браузера |
| vscode, antigravity-ide, discord, obsidian, spotify | Chromium/Electron и GPU-рендер |
| telegram-desktop | Qt/OpenGL |
| obs-studio | OpenGL-композитинг сцен |
| hyprpicker | Единый запуск графического инструмента через GPU-хелпер |
| swaynotificationcenter (swaync) | В закреплённой версии уже GTK4 с GPU-рендерером |

Thunar, Evince, Zathura, Qalculate, Waybar, rofi, nm-applet и pasystray используют
GTK3/Cairo и оставлены без GPU-обёрток. Awww 0.12.1 использует `wl_shm`, а не EGL;
ему обёртка не нужна. Аналогично не оборачиваются swaybg, grim, slurp и CLI.
Niri, Xwayland, hyprlock и hypridle используют системные бинарники Arch.

HM сохраняет `.desktop`-файлы и перенаправляет абсолютные ссылки на обёрнутый пакет.
Записи с `Exec=kitty`, `Exec=firefox` и другими именами находят обёртки через PATH.
Это распространяется на rofi, файловые ассоциации и бинды niri. Для Telegram HM
также переписывает D-Bus activation entry.

NixGL читает `/proc/driver/nvidia/version` через локальную derivation с
`builtins.currentTime`: поэтому сборке/активации нужен `--impure` и доступ к сети
при первом скачивании подходящих библиотек NVIDIA. Версия определяется автоматически.
Никакой NVIDIA `.run`-установщик в системе не запускается.

Закреплённый nixGL `b610529` требует небольшого адаптера `arch/nixgl.nix`:
`nixgl-compat.patch` добавляет распознавание строки `Module for x86_64` у nvidia-open
и убирает удалённый из nixpkgs аргумент `kernel`. Адаптер использует тот же `pkgs`,
что HM (включая unfree/license), корректирует имя Vulkan ICD и направляет EGL
external-platform lookup на Nix-библиотеки Wayland/GBM/X11 внутри процесса.
При обновлении nixGL/nixpkgs эти совместимые правки нужно перепроверить.
См. [интеграцию HM](https://github.com/nix-community/home-manager/blob/fae6e9e42c3b762ab47635cddcfaf6f52374a61b/docs/manual/usage/gpu-non-nixos.md)
и [исходник nixGL](https://github.com/nix-community/nixGL/blob/b6105297e6f0cd041670c3e8628394d4ee247ed5/nixGL.nix).

### Изоляция от других пользователей

Системная часть — существующие общие пакеты Arch и файл
`/var/lib/AccountsService/users/badrabbit`. Установщик изменяет в нём только
`Session`, `SessionType`, `SystemAccount`, сохраняет остальные ключи/комментарии
и перезапускает accounts-daemon. Сессию он берёт из имени
`/usr/share/wayland-sessions/niri.desktop`. Файлы других пользователей не трогает.

Скрипт выполняет `pacman -Syu --needed`, включает общие NetworkManager, Bluetooth
и GDM (без перезапуска GDM). Собственных настроек в `/etc/profile.d`,
`/etc/environment`, EGL/Vulkan, tmpfiles, GDM или dconf он не записывает.
Штатные файлы пакетов и включение трёх общих служб относятся к системной установке.
Новых пакетов относительно прежнего установщика не добавлено; из списка убраны
лишние пользовательские CLI и zsh. Оставшийся явный список:

```text
niri xwayland-satellite hyprlock hypridle
gdm gnome-shell gnome-session accountsservice
xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
nvidia-open nvidia-utils egl-wayland egl-gbm egl-x11 vulkan-icd-loader
networkmanager bluez bluez-utils brightnessctl
pipewire pipewire-pulse wireplumber libpulse
polkit polkit-gnome gnome-keyring udisks2 gvfs fontconfig
util-linux pacman-contrib python sudo
```

Python нужен root-helper для безопасного обновления AccountsService; util-linux,
sudo и pacman-contrib обслуживают системные операции. Программы, оболочка zsh,
CLI, темы и шрифты пользователя устанавливаются Home Manager. Смена login shell
не автоматизирована; если системный zsh уже установлен, `chsh -s /usr/bin/zsh`
можно выполнить **от имени badrabbit**, не для других аккаунтов.

Waybar, swaync, hypridle, polkit-agent, nm-applet, pasystray и опциональный sops-nix
имеют `WantedBy`, `PartOf`, `Requisite` только для `niri.service`. Лишняя привязка
Waybar к `tray.target` удалена на Arch. XDG-autostart tray-программ перекрыт
пользовательскими `Hidden=true` entries; swaync D-Bus activation направлен в
ограниченную службу. Awww и два wl-paste/cliphist watcher запускаются только
`spawn-at-startup` из KDL и живут в cgroup сессии niri. При входе самого `badrabbit`
в GNOME эти фоновые компоненты тоже не должны запускаться.

HM пишет в home только `badrabbit`. В niri и его службах `TMPDIR` направлен в
`$XDG_RUNTIME_DIR`; каталог создаётся logind для своего UID с правами 0700.
Сокет kitty на обеих платформах находится в `$XDG_RUNTIME_DIR/kitty-PID`: kitty
раскрывает переменную и добавляет PID. Внутри kitty достаточно `kitten @ ls`;
явное обращение — `kitten @ --to "$KITTY_LISTEN_ON" ls`.
См. [документацию listen_on](https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.listen_on).

`PATH` содержит `~/.local/bin`, `~/.nix-profile/bin` и
`/nix/var/nix/profiles/default/bin`. HM genericLinux экспортирует профильный `share`
в `XDG_DATA_DIRS`; drop-in niri сохраняет эти пути после импорта окружения GDM.
Fontconfig видит CommitMono/SpaceMono/JetBrainsMono Nerd Fonts и Noto из профиля Nix.

Секреты в store не помещаются: Gemini JSON содержит только настройки/состояние,
SSH-конфиг ссылается на `~/.ssh/id_github`, Context7 читает ключ при запуске.
Для опционального sops задайте в standalone `extraSpecialArgs` **строку**:

```nix
sopsAgeKeyFile = "/home/badrabbit/.config/sops/age/keys.txt";
```

Сам age-ключ хранится вне Git с правами 0600 и должен расшифровывать существующий
encrypted YAML. Sops расшифровывает его пользовательской службой в niri; Context7
читает `~/.config/sops-nix/secrets/context7_api_key`. Без ключа Context7 работает
с ограничением запросов. Не помещайте credentials в `.text`/`.source` или Nix path
literal. В NixOS остаётся прежний системный sops.

### Очистка после прежней GPU-настройки

**Только на Arch, если раньше запускали `non-nixos-gpu-setup`.** На NixOS эти
команды выполнять нельзя. Сначала перейдите на текущую HM generation, затем удалите
остатки прежнего `targets.genericLinux.gpu`:

```sh
sudo rm -f /etc/tmpfiles.d/non-nixos-gpu.conf
sudo sh -c 'rm -f /etc/egl/egl_external_platform.d/*_nix_gpu.json'
sudo rm -f /run/opengl-driver
sudo rm -f /nix/var/nix/gcroots/non-nixos-gpu.conf
```

Последний путь — точный GC root из setup-скрипта закреплённого HM при стандартном
Nix state directory `/nix/var/nix`. Ссылки на остальные EGL JSON не удаляются.
Запуск через `sh` позволяет очистке работать и из zsh, когда glob уже пуст.
Это разовая миграция старой установки, а не шаг установки/обновления нового HM.

### Ограничения и проверка

- **CUDA из Nix на Arch не гарантируется**, её настройка — отдельная задача.
- nixGL меняет окружение процесса и его дочерних процессов. Запуск приложений Arch
  из обёрнутого терминала/IDE может выявить несовместимость библиотек; другие UID
  не наследуют это окружение. EGL/Vulkan и аппаратное декодирование проверяются
  на целевом драйвере, успешная сборка их не подтверждает.
- Hibernate требует отдельной настройки swap/resume. Яркость внешних мониторов
  через DDC/CI не настраивается, battery/backlight скрыты на ARCH-BOX.
- Пользовательские настройки HM действуют для `badrabbit`; изоляция автозапуска
  не означает отдельный домашний каталог для его GNOME и niri.

Проверки без активации:

```sh
nix flake check
nix build --impure '.#homeConfigurations."badrabbit@ARCH-BOX".activationPackage' --out-link result-arch
python3 arch/tests/check-generation.py result-arch
nixos-rebuild build --flake .#badrabbitpc
python3 -m unittest discover -s arch/tests -v
shellcheck arch/setup-system.sh
```

`nix flake check` проходит в pure-режиме, но не строит произвольный
`homeConfigurations` output. Сборка/eval Arch activationPackage без `--impure`
невозможна с автоопределением NVIDIA и выдаёт явное сообщение. NixOS по-прежнему
собирается в pure-режиме; nixGL не участвует в его пакетах.

Ручная проверка на ARCH-BOX:

1. В GDM войдите как `badrabbit`: должна открыться niri без ручного выбора.
   Запустите kitty, Firefox, Chrome, VS Code из rofi и биндов; `nvidia-smi`
   должен видеть RTX 5080 и GPU-процессы. Проверьте Waybar, звук, Bluetooth,
   portals/screencast, шрифты и принятие пароля hyprlock.
2. Проверьте `systemctl --user status waybar swaync hypridle niri-polkit-agent nm-applet pasystray`.
   Для окружения бинда: `niri msg action spawn -- sh -c 'env > "$XDG_RUNTIME_DIR/niri-env"'`,
   затем `grep -E '^(PATH|XDG_DATA_DIRS|TMPDIR)=' "$XDG_RUNTIME_DIR/niri-env"`.
3. Внутри kitty выполните `kitten @ ls`, `echo "$KITTY_LISTEN_ON"` и
   `stat -c '%a %U' "$XDG_RUNTIME_DIR"`: сокет должен быть в личном runtime-каталоге.
4. Войдите другим пользователем в GNOME: `ps -u "$USER" -o comm=` не должен показывать
   наши фоновые компоненты. Проверьте отсутствие старых общесистемных GPU-файлов,
   перечисленных в разделе очистки. Повторите вход в GNOME самим `badrabbit` и
   убедитесь, что niri-службы неактивны.
5. После обновления драйвера перезагрузитесь и повторите HM switch с `--impure`.
   Настройки и автозапуск других пользователей не меняются; сам драйвер Arch общий.

*Forged in blood and code for the Architect.* 🧛‍♀️🩸
