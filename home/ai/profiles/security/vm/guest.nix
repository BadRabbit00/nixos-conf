# Гость стенда активного аудита: одноразовая microvm без сети и без общих папок.
#
#   сеть       нет интерфейсов вообще (только loopback внутри гостя)
#   файлы      нет virtiofs/9p; проект и отчёты ходят по vsock+ssh (sec-vm.sh)
#   корень     tmpfs, store — read-only erofs-диск; погасил VM — состояния нет
#   доступ     ssh по vsock, ключ создаётся на каждую сессию и приходит credential'ом
#   CID        задаётся при запуске (SEC_VM_CID), чтобы сессии не пересекались
#
# Инварианты изоляции закреплены assertions ниже: они срабатывают и при
# nixos-rebuild, и при nix flake check, а не только в проверке раннера.
{ config, pkgs, ... }:

let
  schemathesis = pkgs.callPackage ../schemathesis.nix { };
  # Строже, чем microvm-овское `-sandbox on`: без setuid, fork/exec и смены ресурсов.
  sandboxArgs = [ "-sandbox" "on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny" ];
in
{
  networking = {
    hostName = "sec-vm";
    useDHCP = false;
    dhcpcd.enable = false;
    firewall.enable = false;
  };

  assertions = [
    {
      assertion = config.microvm.interfaces == [ ] && config.microvm.shares == [ ]
        && config.microvm.volumes == [ ] && config.microvm.devices == [ ]
        && config.microvm.forwardPorts == [ ];
      message = "sec-vm: у стенда не должно быть сети, общих папок, томов, проброшенных устройств и портов";
    }
    {
      assertion = !config.microvm.graphics.enable && config.microvm.vsock.cid == null
        && config.microvm.qemu.machine == "microvm" && config.microvm.hypervisor == "qemu";
      message = "sec-vm: графика и фиксированный CID запрещены, машина — microvm на QEMU";
    }
    {
      assertion = config.microvm.qemu.extraArgs == sandboxArgs;
      message = "sec-vm: в qemu.extraArgs допустим только ужесточённый -sandbox";
    }
  ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 4;
    mem = 6144;
    interfaces = [ ];
    shares = [ ];
    volumes = [ ];
    writableStoreOverlay = null;
    registerClosure = false; # Nix внутри не нужен
    # Ужесточение seccomp-песочницы QEMU поверх microvm-овского `-sandbox on`.
    qemu.extraArgs = sandboxArgs;
    # Аргументы QEMU, известные только в момент запуска. Путей хоста нет:
    # раннер стартует в каталоге сессии, ключ лежит в нём как key.pub, CID
    # проверяется. Расширение раннера не режется по пробелам из чужих путей.
    # devType для машины microvm на x86_64 — "device" (lib/runners/qemu.nix).
    extraArgsScript = "${pkgs.writeShellScript "sec-vm-extra-args" ''
      [[ ''${SEC_VM_CID:?} =~ ^[1-9][0-9]{2,9}$ ]] || { echo "sec-vm: bad CID" >&2; exit 1; }
      [[ -f key.pub && ! -L key.pub ]] || { echo "sec-vm: нет ./key.pub" >&2; exit 1; }
      printf '%s' "-device vhost-vsock-device,guest-cid=$SEC_VM_CID -fw_cfg name=opt/io.systemd.credentials/sec-vm.pubkey,file=key.pub"
    ''}";
  };

  fileSystems."/" = {
    device = "rootfs";
    fsType = "tmpfs";
    options = [ "size=3g" "mode=755" ];
  };

  boot.kernelModules = [ "vsock" "vmw_vsock_virtio_transport" ];

  nix.enable = false;
  documentation.enable = false;
  security.sudo.enable = false;
  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true; # входим только по ключу сессии
    users.audit = {
      isNormalUser = true;
      home = "/home/audit";
      createHome = true;
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "audit" ];
      X11Forwarding = false;
      AllowTcpForwarding = false;
      AllowAgentForwarding = false;
    };
    authorizedKeysFiles = [ "/run/sec-vm/authorized_keys" ];
  };

  # Публичный ключ сессии приходит как systemd credential (fw_cfg).
  systemd.services.sec-vm-authkey = {
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" "sshd-vsock.socket" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ImportCredential = "sec-vm.pubkey";
      RuntimeDirectory = "sec-vm";
      RuntimeDirectoryPreserve = true;
      ExecStart = "${pkgs.coreutils}/bin/install -m 0644 %d/sec-vm.pubkey /run/sec-vm/authorized_keys";
    };
  };

  environment.systemPackages = (with pkgs; [
    gnutar gzip coreutils findutils gnugrep gnused gawk bashInteractive
    curl jq openssl ripgrep git python3 nodejs
    # Рантайм аудируемых сервисов: venv проекта собирается на хосте этим же
    # python311 (тот же store path) и приезжает копией проекта; Postgres с
    # pgvector для CRM API и компаньона, redis для кеша CRM. Сеть всё равно
    # отсутствует, слушают только loopback гостя.
    python311 redis
    stdenv.cc.cc.lib # libstdc++ для manylinux-колёс в venv (numpy у pgvector)
    (postgresql_16.withPackages (p: [ p.pgvector ]))
    zap
  ]) ++ [ schemathesis ];

  system.stateVersion = "26.05";
}
