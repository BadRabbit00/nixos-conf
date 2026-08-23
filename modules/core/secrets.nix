{ inputs, ... }:

{
  # Каркас управления секретами через sops-nix.
  # Секреты (GITHUB_TOKEN, API-ключи) шифруются age и коммитятся в репозиторий безопасно.
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Приватный age-ключ (НЕ коммитить!). Сгенерируй один раз:
  #   nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
  # Затем возьми ПУБЛИЧНЫЙ ключ из вывода и пропиши его в .sops.yaml.
  sops.age.keyFile = "/home/BadRabbit/.config/sops/age/keys.txt";

  # --- Активируется после создания зашифрованного файла ---
  # 1. Создай .sops.yaml в корне репо с твоим публичным age-ключом.
  # 2. Создай и зашифруй секреты:
  #      nix shell nixpkgs#sops -c sops modules/core/secrets/secrets.yaml
  # 3. Раскомментируй строки ниже и объяви нужные секреты:
  #
  # sops.defaultSopsFile = ./secrets/secrets.yaml;
  # sops.secrets.github_token = { owner = "BadRabbit"; };
}
