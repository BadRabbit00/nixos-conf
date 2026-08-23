{ config, pkgs, lib, ... }:

{
  # 🩸 Оставляем ideapad_laptop (он нужен для базовых функций типа FnLock и Battery Conservation)
  # Но форсируем загрузку legion-laptop, так как новые модели (Gen 9) еще не в белом списке
  boot.extraModprobeConfig = ''
    options legion-laptop force=1
  '';

  # ⚡ Максимальная производительность процессора (5+ GHz)
  powerManagement.cpuFreqGovernor = lib.mkForce "performance";

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

  # ⚙️ Правила udev для доступа юзера
  services.udev.extraRules = ''
    SUBSYSTEM=="platform", DRIVER=="legion", RUN+="${pkgs.coreutils}/bin/chmod -R a+rw /sys/module/legion_laptop/drivers/platform:legion/"
    SUBSYSTEM=="platform", DRIVER=="ideapad_acpi", RUN+="${pkgs.coreutils}/bin/chmod -R a+rw /sys/bus/platform/drivers/ideapad_acpi/"
  '';

  services.udev.packages = [ pkgs.lenovo-legion ];

  # 🛑 Убиваем power-profiles-daemon, он конфликтует с legion-laptop
  services.power-profiles-daemon.enable = false;

  # 🚀 Авто-применение Custom режима и Power Limits при старте
  systemd.services.legion-power-limits = {
    description = "Apply Lenovo Legion Custom Power Limits for i9-14900HX";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    path = [ pkgs.lenovo-legion ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "legion-power-limits" ''
        legion_cli set-feature PlatformProfileFeature custom || true
        legion_cli set-feature CPULongtermPowerLimit 130 || true
        legion_cli set-feature CPUShorttermPowerLimit 175 || true
        legion_cli set-feature CPUPeakPowerLimit 180 || true
        legion_cli set-feature CPUCrossLoadingPowerLimit 100 || true
      '';
    };
  };

  # 🌪 Агрессивный термоконтроль: Вентиляторы на MAX при >= 80°C
  systemd.services.legion-fan-control = {
    description = "Lenovo Legion Aggressive Fan Control";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    path = [ pkgs.lenovo-legion pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      ExecStart = pkgs.writeShellScript "legion-fan-control" ''
        MAX_SPEED_ENABLED=0
        while true; do
          TEMP=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -n1)
          if [ -n "$TEMP" ]; then
            if [ "$TEMP" -ge 80000 ] && [ "$MAX_SPEED_ENABLED" -eq 0 ]; then
              legion_cli maximumfanspeed-enable
              MAX_SPEED_ENABLED=1
            elif [ "$TEMP" -le 70000 ] && [ "$MAX_SPEED_ENABLED" -eq 1 ]; then
              legion_cli maximumfanspeed-disable
              MAX_SPEED_ENABLED=0
            fi
          fi
          sleep 2
        done
      '';
    };
  };
}
