# Инструменты Nix-toolkit. Сами агенты (nix-architect, nix-engineer, nix-reviewer,
# nix-build-resolver, nix-test-runner), команды /nix-* и скиллы-справочники
# (nix-toolkit, nix-flake-patterns, project-flake, nixos-module-patterns,
# nix-packaging, nix-testing, nix-debugging) живут в репозитории
# BadRabbit00/warren (ветка develop) и приходят через home/ai/warren.
# Справочники зовут эти бинари по имени, поэтому они стоят декларативно,
# а не через `nix shell`.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    statix              # линтер анти-паттернов
    deadnix             # мёртвый код
    nixfmt              # форматтер (RFC style)
    nvd                 # diff двух closure/поколений
    nix-tree            # TUI дерева зависимостей
    nix-output-monitor  # nom: граф сборки
    nix-diff            # diff двух .drv
    nurl                # fetcher-выражение с хэшем по URL
    nix-init            # черновик пакета из репозитория
    nix-prefetch-git
    nixpkgs-review      # проверка PR в nixpkgs
    nil                 # LSP
  ];
}
