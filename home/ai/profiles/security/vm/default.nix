# Стенд активного аудита `sec-vm`: одноразовая microvm без сети (см. guest.nix)
# и обёртка, через которую агент ей управляет по vsock+ssh.
#
#   sec-vm up [--ttl H] [--with-git] [--max-mb N] <проект>   поднять, скопировать проект
#   sec-vm exec <id> <команда>                              выполнить внутри
#   sec-vm pull <id>                                        забрать .sec/reports
#   sec-vm down <id> | list
{ pkgs, inputs }:

let
  guest = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [ inputs.microvm.nixosModules.microvm ./guest.nix ];
  };
  runner = guest.config.microvm.declaredRunner;
  extraArgs = guest.config.microvm.extraArgsScript;

  sec-vm = pkgs.writeShellApplication {
    name = "sec-vm";
    runtimeInputs = with pkgs; [
      openssh socat gnutar coreutils findutils gnugrep gnused gawk util-linux procps
    ];
    text = ''
      SEC_VM_RUNNER=${runner}/bin/microvm-run
      ${builtins.readFile ./sec-vm.sh}
    '';
  };

  # Страховка поверх assertions в guest.nix: в итоговом запуске QEMU не должно
  # быть сети, общих папок, проброса устройств; обязательны -nodefaults и песочница.
  isolationCheck = pkgs.runCommand "sec-vm-isolation-check" { } ''
    script=${runner}/bin/microvm-run
    extra=${extraArgs}
    [ -s "$script" ] && [ -s "$extra" ] || { echo "sec-vm: нет раннера или extraArgs" >&2; exit 1; }
    for bad in -netdev -nic '-net ' virtio-net virtfs virtiofs -fsdev -usb usb-host \
               qemu-xhci vfio vhost-user memory-backend-memfd hostfwd 'user,' passt; do
      if grep -qF -- "$bad" "$script" "$extra" ${runner}/share/microvm/* 2>/dev/null; then
        echo "sec-vm: в раннере найдено запрещённое: $bad" >&2
        exit 1
      fi
    done
    for need in -nodefaults 'usb=off' 'pcie=off' 'read-only=on' \
                'obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny'; do
      grep -qF -- "$need" "$script" || { echo "sec-vm: в раннере нет обязательного: $need" >&2; exit 1; }
    done
    touch $out
  '';
in
{
  inherit sec-vm runner isolationCheck;
}
