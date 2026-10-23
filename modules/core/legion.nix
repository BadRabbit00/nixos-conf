{ config, pkgs, lib, ... }:

{
  # 🩸 Оставляем ideapad_laptop (он нужен для базовых функций типа FnLock и Battery Conservation)
  # Но форсируем загрузку legion-laptop, так как новые модели (Gen 9) еще не в белом списке
  boot.extraModprobeConfig = ''
    options legion-laptop force=1
  '';

  # ⚡ Governor и профиль прошивки живут в power.nix: от сети performance,
  # на батарее powersave + balanced. Статичный performance на батарее стоил 28 Вт в простое.

  # 💉 Внедряем проприетарный модуль LenovoLegionLinux
  boot.extraModulePackages = with config.boot.kernelPackages; [
    lenovo-legion-module
  ];
  boot.kernelModules = [ "legion-laptop" ];

  # 🔧 Инструментарий для управления турбинами (CLI + GUI)
  environment.systemPackages = with pkgs; [
    (symlinkJoin {
      name = "lenovo-legion-wrapped";
      paths = [ lenovo-legion ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/legion_gui \
          --unset QT_QPA_PLATFORMTHEME \
          --unset QT_STYLE_OVERRIDE
      '';
    })
  ];

  # ⚠️ Никаких chmod на /sys/bus/platform/drivers/*: uevent драйвера write-only,
  # после a+rw udevadm trigger читает его, ловит EIO и отменяет coldplug целиком,
  # и /boot с /mnt/windows не монтируются. Атрибуты устройства это всё равно не открывало.
  services.udev.packages = [ pkgs.lenovo-legion ];

  # 🛑 Убиваем power-profiles-daemon, он конфликтует с legion-laptop
  services.power-profiles-daemon.enable = false;

  # 🌪 Агрессивный термоконтроль: вентиляторы на MAX при CPU/GPU >= 80°C.
  # Работает ТОЛЬКО в профиле custom: драйвер отвечает EBUSY с «fan_fullspeed needs
  # powermode 255 (custom)» в любом другом. В performance/balanced кривой рулит прошивка,
  # и цикл просто спит. Профиль от сети задаётся в power.nix (acProfile).
  # Температуры берём из legion_hwmon (CPU и GPU), а не из всех thermal_zone:
  # датчик корпуса SEN5 держит 75°C в простое и загонял бы турбины на максимум зря.
  # bash в path обязателен: legion_cli вызывает его и без него падает на старте.
  systemd.services.legion-fan-control = {
    description = "Lenovo Legion Aggressive Fan Control";
    wantedBy = [ "multi-user.target" ];
    # Без legion_hwmon нет смысла долбиться вечно: 5 попыток за 5 минут и стоп.
    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    path = [ pkgs.bash ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
      PrivateNetwork = true;
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      # Остановка службы не должна оставлять турбины на максимуме.
      ExecStopPost = lib.getExe (pkgs.writeShellApplication {
        name = "legion-fan-control-release";
        runtimeInputs = with pkgs; [ bash coreutils lenovo-legion ];
        text = ''
          # Вне custom снимать нечего, а legion_cli ответил бы EBUSY с трейсбеком в журнал.
          [ "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)" = custom ] || exit 0
          legion_cli maximumfanspeed-disable
        '';
      });
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "legion-fan-control";
        runtimeInputs = with pkgs; [ bash coreutils lenovo-legion ];
        text = ''
          hwmon=""
          for name in /sys/class/hwmon/hwmon*/name; do
            if [ "$(cat "$name")" = legion_hwmon ]; then
              hwmon="$(dirname "$name")"
              break
            fi
          done
          if [ -z "$hwmon" ]; then
            echo "legion-fan-control: legion_hwmon not found, is legion-laptop loaded?" >&2
            exit 1
          fi

          profile_is_custom() {
            [ "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)" = custom ]
          }

          # После рестарта (Restart=always, nixos-rebuild switch) EC может всё ещё
          # крутить максимум, а наша переменная уже 0. Приводим к известному состоянию.
          if profile_is_custom; then
            legion_cli maximumfanspeed-disable 2>/dev/null || true
          fi
          max_speed_enabled=0
          while true; do
            if ! profile_is_custom; then
              max_speed_enabled=0
              sleep 10
              continue
            fi
            # || true: один EIO от EC на чтении датчика не должен ронять демон.
            temp=$(cat "$hwmon"/temp[12]_input 2>/dev/null | sort -nr | head -n1 || true)
            if [ -n "$temp" ]; then
              if [ "$temp" -ge 80000 ] && [ "$max_speed_enabled" -eq 0 ]; then
                legion_cli maximumfanspeed-enable && max_speed_enabled=1
              elif [ "$temp" -le 70000 ] && [ "$max_speed_enabled" -eq 1 ]; then
                legion_cli maximumfanspeed-disable && max_speed_enabled=0
              fi
            fi
            sleep 2
          done
        '';
      });
    };
  };
}
