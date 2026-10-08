{ inputs, ... }:

{
  # Управление секретами через sops-nix: зашифрованное коммитим, ключ — никогда.
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Приватный age-ключ. Лежит в репозитории, но в .gitignore и НЕ в /nix/store:
  # путь передаётся строкой, файл читается root-ом уже при активации системы.
  # Пересоздать: nix shell nixpkgs#age -c age-keygen -o /home/BadRabbit/nixos-conf/.key
  # (после этого перешифровать секреты новым публичным ключом из .sops.yaml).
  sops.age.keyFile = "/home/BadRabbit/nixos-conf/.key";

  # БЕЗ ЭТОГО КЛЮЧ НЕДОСТУПЕН ПРИ ЗАГРУЗКЕ.
  # /home у нас отдельная btrfs-подтома (@home на nvme1n1p2), а обычный
  # activationScript выполняется в stage-2 ДО того, как systemd смонтирует
  # неboot-овые ФС. Ключа в этот момент физически нет -> /run/secrets пуст
  # до следующего ручного switch. Systemd-юнит же умеет RequiresMountsFor и
  # сам дожидается монтирования каталога с ключом.
  sops.useSystemdActivation = true;

  sops.defaultSopsFile = ./secrets/secrets.yaml;

  # Расшифровывается в /run/secrets/<имя> — это tmpfs, на диск не ложится.
  # owner нужен, иначе файл достанется только root, а MCP-сервер бежит от юзера.
  sops.secrets.context7_api_key = {
    owner = "BadRabbit";
    mode = "0400";
  };
}
