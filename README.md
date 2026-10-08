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

Один каталог `home/` используется двумя выходами флейка:

| Выход | Пользователь | Домашний каталог | Режим |
| --- | --- | --- | --- |
| `nixosConfigurations.badrabbitpc` | `BadRabbit` | `/home/BadRabbit` | HM как модуль NixOS, `isNixOS = true` |
| `homeConfigurations."badrabbit@ARCH-BOX"` | `badrabbit` | `/home/badrabbit` | standalone HM, `isNixOS = false` |

Все различия пользовательских модулей проходят через `isNixOS`. Системные модули
`hosts/` и `modules/` на Arch не импортируются. На Arch **не запускайте `setup.sh`
из корня**: он предназначен для переименования NixOS-конфига.

### Граница между pacman и Home Manager

`arch/setup-system.sh` устанавливает системную часть через pacman: niri и регистрацию
его сессии для GDM, Xwayland, PAM для hyprlock, hypridle, драйвер NVIDIA, порталы,
звук, сеть, Bluetooth, polkit, udev-правила и необходимые системные утилиты.
Скрипт включает NetworkManager и Bluetooth, включает GDM на следующую загрузку
без перезапуска текущего экрана входа. Он выполняет полный `pacman -Syu --needed`;
при конфликте пакетов pacman запрашивает решение, частичное обновление не делается.

HM устанавливает пользовательские программы (kitty, rofi, браузеры, Waybar,
swaync, awww, редакторы, CLI), конфиги, скрипты, темы и шрифты. Он создаёт только
пользовательские службы hypridle и polkit-agent для niri, вызывающие бинарники Arch.
NetworkManager applet, Thunar и другие D-Bus-клиенты могут быть из Nix, но их
системные службы предоставляет Arch. Установка пакета в closure Nix сама по себе
не регистрирует системную службу, PAM или udev-правила.

Полный явный список pacman (зависимости pacman разрешает дополнительно):

```text
niri xwayland-satellite hyprlock hypridle
gdm gnome-shell gnome-session accountsservice
xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
nvidia-open nvidia-utils egl-wayland egl-gbm egl-x11 vulkan-icd-loader
networkmanager bluez bluez-utils brightnessctl
pipewire pipewire-pulse wireplumber libpulse
polkit polkit-gnome gnome-keyring udisks2 gvfs fontconfig
bash zsh coreutils util-linux procps-ng gawk grep sed curl pacman-contrib python sudo
```

Назначение каждого пакета также указано рядом с ним в `arch/setup-system.sh`.
`nmcli` приходит из networkmanager, `bluetoothctl` — из bluez-utils, `wpctl` — из
wireplumber, `pactl` — из libpulse, `rfkill`/`logger` — из util-linux,
`pidof`/`pkill`/`watch` — из procps-ng, `checkupdates` — из pacman-contrib.

### Первая установка

Предполагается уже работающий Arch x86_64 с GDM/GNOME, пользователем `badrabbit`,
hostname `ARCH-BOX`, Nix daemon и включёнными `nix-command flakes`. Скрипт не
создаёт пользователей, не меняет hostname, разметку btrfs или настройки Nix.
Пакет `nvidia-open` рассчитан на стандартное ядро Arch `linux`; при другом ядре
нужно сначала согласовать пакет модулей NVIDIA с ядром.

Из клона репозитория, принадлежащего `badrabbit`:

```sh
sudo ./arch/setup-system.sh
./arch/sync-nvidia.sh
nix run home-manager/master -- switch --flake .#badrabbit@ARCH-BOX -b backup
sudo "$(readlink -f "$HOME/.nix-profile/bin/non-nixos-gpu-setup")"
```

`sync-nvidia.sh` выполняется **без sudo**, читает `pacman -Q nvidia-utils`, скачивает
официальный `.run`-архив NVIDIA только для вычисления hash и обновляет
отслеживаемый `arch/nvidia-driver.json`. Он не запускает установщик NVIDIA.
Первоначальный pin — `615.71.09` из закреплённого nixpkgs; до первой активации
обязательно синхронизируйте его с установленным драйвером ARCH-BOX.

Команда с `home-manager/master` приведена для bootstrap; сам конфиг использует
HM из `flake.lock`. Для bootstrap CLI той же закреплённой версии можно использовать:

```sh
nix run --inputs-from . home-manager -- switch --flake .#badrabbit@ARCH-BOX -b backup
```

После установки выйдите из всех сессий `badrabbit` и войдите заново; после обновления
ядра или NVIDIA перезагрузитесь. При необходимости смените login shell только
своего пользователя: `chsh -s /usr/bin/zsh`.

GDM получает сессию из `/usr/share/wayland-sessions/niri.desktop`.
Установщик меняет только `Session=niri`, `SessionType=wayland`,
`SystemAccount=false` в секции `[User]` файла
`/var/lib/AccountsService/users/badrabbit`, сохраняя остальные ключи и комментарии,
после чего перезапускает `accounts-daemon`. Повторный запуск безопасен.
Файлы остальных пользователей и глобальная сессия GDM не меняются; существующий
GNOME остаётся их сессией. Если другой пользователь ранее сам выбирал иную сессию,
его сохранённый выбор тоже остаётся прежним.

GDM проверяет пароль при входе. В niri на Arch нет дополнительного hyprlock при
старте; блокировка запускается `Mod+L`, через loginctl или hypridle спустя 300 секунд,
экран выключается спустя 330 секунд. На NixOS остаётся исходная цепочка greetd и
hyprlock при старте.

### Обновления и NVIDIA

Обычное обновление пользовательского окружения:

```sh
home-manager switch --flake .#badrabbit@ARCH-BOX
```

При совпадении `$USER@$(hostname)` с `badrabbit@ARCH-BOX` достаточно
`home-manager switch --flake .`. В новой сессии CLI доступен из `~/.nix-profile/bin`.

Закреплённый HM поддерживает `targets.genericLinux.gpu.nvidia`: он собирает
совместимые с nixpkgs пользовательские библиотеки драйвера. `nvidia-open` обозначает
открытый **модуль ядра**; ему всё равно нужны пользовательские NVIDIA-библиотеки
из `nvidia-utils`. Версия библиотек в Nix должна точно совпадать с версией драйвера
хоста; версия пакета Arch без epoch и `-pkgrel` — нужная upstream-версия.
См. [документацию Home Manager по GPU](https://github.com/nix-community/home-manager/blob/fae6e9e42c3b762ab47635cddcfaf6f52374a61b/docs/manual/usage/gpu-non-nixos.md).

После каждого обновления `nvidia-open`/`nvidia-utils` через pacman:

```sh
pacman -Q nvidia-open nvidia-utils
./arch/sync-nvidia.sh
home-manager switch --flake .#badrabbit@ARCH-BOX
sudo "$(readlink -f "$HOME/.nix-profile/bin/non-nixos-gpu-setup")"
./arch/sync-nvidia.sh --check
# Перезагрузитесь, чтобы ядро загрузило новую версию модуля NVIDIA.
```

Сохраните изменение `arch/nvidia-driver.json` отдельным коммитом. Обновление только
`flake.lock` не синхронизирует этот pin. При необходимости hash можно получить
вручную через `nix store prefetch-file` для URL, используемого скриптом.

HM при активации лишь печатает предупреждение и точную команду с sudo, если GPU
библиотеки требуют установки/обновления. Root запускается отдельно: upstream-скрипт
создаёт `/etc/tmpfiles.d/non-nixos-gpu.conf`, GC root и `/run/opengl-driver`, а для
NVIDIA также ссылки EGL в `/etc/egl/egl_external_platform.d/`. Tmpfiles восстанавливает
их после перезагрузки. Это системная операция, её нельзя выполнить автоматически
из активации HM. Не запускайте этот helper на NixOS: там `/run/opengl-driver`
принадлежит NixOS. Используется штатная GPU-интеграция HM, обёртки nixGL не нужны.

### Окружение, секреты и ограничения

`home/generic-linux.nix` добавляет `~/.local/bin`, `~/.nix-profile/bin` и
`/nix/var/nix/profiles/default/bin` в окружение shell и `environment.d`.
`targets.genericLinux` сам добавляет профильные `share`-каталоги в `XDG_DATA_DIRS`,
в том числе для systemd user. Дополнительный drop-in для системного `niri.service`
фиксирует PATH и XDG_DATA_DIRS: `niri-session` импортирует окружение GDM и может
перезаписать значения user manager. Сессионные бинды поэтому не зависят от запуска
терминала. Niri/Xwayland используют системные бинарники, Xwayland на Arch запускается
по требованию без принудительного `DISPLAY=:0`.

На Arch включён `fonts.fontconfig.enable`, установлены CommitMono, SpaceMono,
JetBrainsMono Nerd Fonts, Noto Emoji и CJK. Catppuccin в `home/` используется как
пакеты GTK/Kvantum, опций `catppuccin.*` там нет: HM-модуль Catppuccin не требуется.
Системный Catppuccin на NixOS сохранён. Оба выхода получают HM-модуль sops из одного
списка `sharedHomeModules`; NixOS по-прежнему расшифровывает системные секреты.

На Arch Context7 по умолчанию работает без API-ключа, с ограничением запросов.
Для sops перенесите age-ключ защищённым способом за пределы репозитория, задайте
права `0600` и в standalone `extraSpecialArgs` укажите, например:

```nix
sopsAgeKeyFile = "/home/badrabbit/.config/sops/age/keys.txt";
```

Это должна быть **строка**, не Nix path literal: содержимое приватного ключа не
должно попасть в store. Ключ должен расшифровывать существующий encrypted YAML;
при новом age-ключе сначала добавьте получателя и перешифруйте секреты. HM запустит
пользовательский `sops-nix.service`; Context7 прочитает секрет через
`~/.config/sops-nix/secrets/context7_api_key`. Проверяйте службу командой
`systemctl --user status sops-nix`, не печатая секрет. SSH продолжает использовать
`~/.ssh/id_github`: этот приватный ключ переносится отдельно.

Ограничения, зависящие от машины:

- На ARCH-BOX скрыты laptop-модули battery/backlight в Waybar. `brightnessctl`
  работает только с устройствами в `/sys/class/backlight`; яркость внешнего
  монитора через DDC/CI здесь не настраивается. Масштаб выходов задаётся общим KDL;
  для другого имени/размера монитора может понадобиться отдельное правило.
- Hibernate из меню требует настроенных swap/resume на Arch; скрипт этого не делает.
- NixOS-специфичные Docker, Steam, llama-server/CUDA и специализации не переносятся
  этим пользовательским выходом. `system-update.sh` обновляет pacman/AUR при наличии
  helper; Home Manager и GPU pin после него обновляются отдельно.
- GTK/Qt-приложения из Nix и Arch могут различаться версиями плагинов. Монтирование
  дисков через Thunar/GVfs, portals/screencast и блокировку PAM нужно проверить в
  живой сессии. GDM не запускает конфиги HM для других пользователей.
- Оверлей patool применяется к обоим выходам. Отдельный общий фикс Tela удаляет
  только битые upstream-ссылки, из-за которых версия `2026-07-07` не собиралась;
  рабочие иконки и настройки темы сохранены.

### Проверка

Без применения конфигурации:

```sh
nix flake check
nix build .#homeConfigurations.\"badrabbit@ARCH-BOX\".activationPackage
nixos-rebuild build --flake .#badrabbitpc
python3 -m unittest discover -s arch/tests -v
shellcheck arch/setup-system.sh arch/sync-nvidia.sh
```

На живой ARCH-BOX после активации и нового входа:

1. В GDM выберите `badrabbit`: должен открыться niri без ручного выбора сессии.
   Проверьте отдельный вход другого пользователя в GNOME.
2. Запустите kitty, rofi и браузер биндами, проверьте сетевое/Bluetooth/звуковое меню
   Waybar. `systemctl --user status niri waybar hypridle niri-polkit-agent` должен
   показывать работающие службы; ошибки смотрите через `journalctl --user -b`.
3. Проверьте окружение именно запуска из niri и наличие Nix desktop entries:
   ```sh
   niri msg action spawn -- sh -c 'env > "$HOME/.cache/niri-env.txt"'
   grep -E '^(PATH|XDG_DATA_DIRS)=' ~/.cache/niri-env.txt
   systemctl --user show-environment | grep -E '^(PATH|XDG_DATA_DIRS)='
   ls ~/.nix-profile/share/applications
   ```
4. `nvidia-smi` должен видеть RTX 5080; `./arch/sync-nvidia.sh --check` должен
   подтвердить версию. Проверьте `readlink /run/opengl-driver` и запуск
   `~/.nix-profile/bin/kitty --debug-rendering` без ошибок EGL/OpenGL.
5. `loginctl lock-session` и ожидание idle должны запускать `/usr/bin/hyprlock`,
   который принимает пароль. Проверьте также suspend/resume.
6. `fc-match 'CommitMono Nerd Font'` и `fc-match 'SpaceMono Nerd Font'` должны находить
   установленные шрифты. Проверьте иконки в kitty и Waybar визуально.
7. Проверьте file chooser/демонстрацию экрана в браузере и
   `systemctl --user status xdg-desktop-portal xdg-desktop-portal-gnome pipewire wireplumber`.
   Если в существующем профиле звук был отключён, включите **от имени badrabbit**:
   `systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service`.

Сборка на NixOS не подтверждает работу GPU, GDM, PAM, устройств или PATH живой
Arch-сессии; перечисленные проверки выполняются на целевой машине.

*Forged in blood and code for the Architect.* 🧛‍♀️🩸
