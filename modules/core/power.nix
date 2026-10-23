{ config, pkgs, lib, ... }:

# 🩸 Профили питания AC / батарея для i9-14900HX + RTX 5060 Ti.
#
# Диагноз (2026-10-22): на батарее ноут отдавал 56–63 Вт при 2–5 % загрузки.
# Пакет CPU ел 26–28 Вт в простое (governor + EPP = performance, пакетные
# C-состояния PC3/PC6/PC8 = 0 % из-за pcie_aspm=off), GPU висел в P8 на 6 Вт
# (pcie_port_pm=off не давал уйти в D3cold). legion-power-limits ни разу не
# применился: legion_cli падал с «No such file: bash» — в PATH службы не было bash.
#
# Решение: одна служба power-profile, которую дёргает udev при смене ADP0,
# загрузка и выход из сна. От сети — governor performance + профиль performance,
# на батарее — powersave + EPP balance_power + профиль balanced + ASPM + Wi-Fi PS.
# Частота экрана не трогается (240 Гц по желанию Архитектора).
#
# Лимиты мощности (PL1/PL2) здесь НЕ пишутся, и это проверено на железе:
#   * MSR через powercap залочен BIOS (ENODATA);
#   * legion_cli CPU*PowerLimit на этой модели пишет «в несуществующий файл»;
#   * штатные ppt_pl*-атрибуты lenovo-wmi-other отвечают EINVAL, потому что
#     внешний legion_wmi забрал GameZone-GUID и lenovo-wmi-gamezone не поднялся.
# Профиль — единственный рабочий рычаг прошивки, им и управляем.
#
# Профиль от сети. Замер 2026-10-22, stress-ng на 24 ядрах, 20 с:
#   performance: 3822 МГц, 151 Вт пакета, 93 °C
#   custom:      3620 МГц, 125 Вт пакета, 92 °C  (лимиты custom прошивка хранит сама)
# Зато только в custom драйвер legion_laptop разрешает fan_fullspeed, то есть
# форсаж вентиляторов из legion-fan-control. Выбор: мощность или ручной обдув.

let
  acProfile = "performance";

  # Battery conservation (стоп заряда на ~80 %). Прошивка сбрасывает флаг сама по себе
  # (после сна, обновления EC), поэтому пишем его при каждом срабатывании профиля,
  # а не один раз при загрузке. Rapid charging с ним уживается — проверено 2026-10-22.
  batteryConservation = true;

  powerProfile = pkgs.writeShellApplication {
    name = "power-profile";
    runtimeInputs = with pkgs; [ coreutils iw ];
    text = ''
      mode="''${1:-auto}"
      adapter=/sys/class/power_supply/ADP0/online

      if [ "$mode" = auto ]; then
        if [ -r "$adapter" ] && [ "$(cat "$adapter")" = 1 ]; then
          mode=ac
        else
          mode=battery
        fi
      fi

      # Пишем в sysfs только если атрибут существует; отказ ядра логируем, не падаем.
      sysfs_write() {
        local path="$1" value="$2"
        if [ -e "$path" ]; then
          printf '%s' "$value" > "$path" || echo "power-profile: write $value -> $path refused" >&2
        else
          echo "power-profile: skip $path (absent)" >&2
        fi
      }

      set_cpu() {
        local governor="$1" epp="$2" cpu
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
          sysfs_write "$cpu/scaling_governor" "$governor"
          sysfs_write "$cpu/energy_performance_preference" "$epp"
        done
      }

      # Пишем в обработчик напрямую: легаси-агрегатор /sys/firmware/acpi/platform_profile
      # на 6.18 отвергает часть значений (EINVAL на custom), а обработчик принимает всё.
      set_platform_profile() {
        local profile="$1" handler
        for handler in /sys/class/platform-profile/platform-profile-*/profile; do
          [ -e "$handler" ] && sysfs_write "$handler" "$profile" && return 0
        done
        sysfs_write /sys/firmware/acpi/platform_profile "$profile"
      }

      set_battery_conservation() {
        local state="$1" node
        for node in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
          [ -e "$node" ] || continue
          sysfs_write "$node" "$state"
          return 0
        done
        echo "power-profile: ideapad conservation_mode not found" >&2
      }

      set_wifi_powersave() {
        local state="$1" dev
        for dev in /sys/class/net/*/wireless; do
          [ -e "$dev" ] || continue
          iw dev "$(basename "$(dirname "$dev")")" set power_save "$state" \
            || echo "power-profile: wifi power_save $state failed" >&2
        done
      }

      set_battery_conservation ${if batteryConservation then "1" else "0"}

      case "$mode" in
        ac)
          echo "power-profile: AC — full power"
          set_platform_profile ${acProfile}
          set_cpu performance performance
          sysfs_write /sys/module/pcie_aspm/parameters/policy default
          set_wifi_powersave off
          ;;
        battery)
          echo "power-profile: battery — power save"
          set_platform_profile balanced
          set_cpu powersave balance_power
          sysfs_write /sys/module/pcie_aspm/parameters/policy powersupersave
          set_wifi_powersave on
          ;;
        *)
          echo "usage: power-profile [auto|ac|battery]" >&2
          exit 64
          ;;
      esac
    '';
  };

  # oneshot + RemainAfterExit остаётся active (exited), поэтому повторный запуск
  # делается через restart: `start` на активном юните — no-op.
  reapply = "${config.systemd.package}/bin/systemctl restart --no-block power-profile.service";
in
{
  environment.systemPackages = [ powerProfile ];

  # Губернатор задаёт power-profile по состоянию адаптера, а не статикой на весь срок.
  # Это единственное определение опции; cpufreq.service при null не генерируется.
  powerManagement.cpuFreqGovernor = null;

  systemd.services.power-profile = {
    description = "Apply AC/battery power profile (CPU governor/EPP, platform profile, ASPM, Wi-Fi)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe powerProfile} auto";
      # Нужны записи в /sys и netlink для iw; ProtectKernelTunables и PrivateNetwork
      # поэтому исключены намеренно.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  # Смена адаптера, появление wlan после coldplug, выход из сна → перечитать профиль.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ACTION=="change", RUN+="${reapply}"
    SUBSYSTEM=="net", ACTION=="add", ENV{DEVTYPE}=="wlan", RUN+="${reapply}"
  '';
  powerManagement.resumeCommands = reapply;
}
