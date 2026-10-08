{ pkgs, lib, ... }:

let
  # Профилактический balance с низким порогом: перепаковывает только те блок-группы,
  # что заполнены меньше чем на 20%. Дёшево по I/O (секунды вместо минут), но не даёт
  # `Device unallocated` сползти к нулю.
  #
  # Почему это вообще нужно: btrfs нарезает диск на чанки заранее. Когда unallocated
  # исчерпан, новый Metadata-чанк выделить нельзя — и ядро отдаёт ENOSPC даже при
  # десятках «свободных» гигабайт в df. Ровно это случилось 15.09.2026: unallocated
  # упал до 1.00 MiB при 23 GB свободных, система задыхалась на I/O.
  btrfs-balance-light = pkgs.writeShellApplication {
    name = "btrfs-balance-light";
    runtimeInputs = [ pkgs.btrfs-progs ];
    text = ''
      echo "=== btrfs usage ДО balance ==="
      btrfs filesystem usage /

      # -dusage/-musage=20 — только почти пустые чанки. Тяжёлые проходы (50+)
      # делаются руками при разборе инцидента, не по таймеру.
      btrfs balance start -dusage=20 -musage=20 /

      echo "=== btrfs usage ПОСЛЕ balance ==="
      btrfs filesystem usage /
    '';
  };
in
{
  systemd.services.btrfs-balance-light = {
    description = "Light btrfs balance (reclaim unallocated space)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe btrfs-balance-light;
      # Не мешаем Архитектору работать: диск отдаём только когда он простаивает.
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      Nice = 19;
    };
    # Legion — ноутбук. На батарее балансировать 200 GB это преступление.
    unitConfig.ConditionACPower = true;
  };

  systemd.timers.btrfs-balance-light = {
    description = "Weekly light btrfs balance";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;      # пропустили из-за выключенной машины — догоним
      RandomizedDelaySec = "1h";
    };
  };

  # Проверка целостности данных по контрольным суммам. btrfs умеет обнаруживать
  # тихое повреждение (bitrot), но только если его об этом попросить.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}
