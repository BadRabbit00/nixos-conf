# Скиллы (SKILL.md) для claude-code, codex и agy: одно объявление — все агенты.
#
# Формат у всех троих один и тот же (каталог с SKILL.md + frontmatter), разные
# только корни, откуда агент их подбирает:
#   claude — ~/.claude/skills/<name>
#   codex  — $CODEX_HOME/skills/<name> (по умолчанию ~/.codex/skills)
#   agy    — ~/.gemini/config/skills/<name> (глобальный customization root)
#
# Скиллы собираются в /nix/store и раскладываются через home.file поштучными
# симлинками (recursive): каталог скилла остаётся настоящим, агентам не нужно
# уметь ходить по симлинку на каталог, а стор остаётся read-only.
{ lib, pkgs, ... }:

let
  # arena — турнир на выбывание между N сабагентами над одной задачей.
  # https://github.com/Jakeschincariol/arena-skill (MIT)
  arenaSrc = pkgs.fetchFromGitHub {
    owner = "Jakeschincariol";
    repo = "arena-skill";
    rev = "df07b8e518e10cdecd8cd7712d9958b6f396250e";
    hash = "sha256-WykjxGGwoM+VZ1k2CK/TNd64ju3vwWZm/qybrA7MhuM=";
  };

  # Апстрим зовёт `python3 "${CLAUDE_SKILL_DIR}/bracket.py"`: интерпретатор из
  # случайного PATH и переменная, которую выставляет только Claude Code (codex и
  # agy её не знают). Агент получает единственную точку входа — обёртку, чьё
  # окружение целиком задано runtimeInputs и запинено flake.lock. Это тот же
  # `nix shell`, только без сети и плавающего nixpkgs из registry в рантайме.
  # bracket.py — чистый stdlib; понадобятся пакеты — доливать сюда.
  arenaBracket = pkgs.writeShellApplication {
    name = "arena-bracket";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${arenaSrc}/skills/arena/bracket.py "$@"'';
  };

  arena = pkgs.stdenvNoCC.mkDerivation {
    pname = "arena-skill";
    version = "0-unstable-2026-09-26";
    src = arenaSrc;

    dontConfigure = true;
    dontBuild = true;

    # Апстримные тесты гоняем на том же python3, что сидит в обёртке.
    doCheck = true;
    nativeCheckInputs = [ pkgs.python3 ];
    checkPhase = ''
      runHook preCheck
      python3 -m unittest discover -s tests -v
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      cp -r skills/arena "$out"
      cp LICENSE "$out/LICENSE"
      rm -r "$out/bracket.py" "$out/__pycache__" # только через обёртку; кэш — от checkPhase
      substituteInPlace "$out/SKILL.md" \
        --replace-fail 'goes through `bracket.py` in this skill'"'"'s folder:' \
                       'goes through `bracket.py`, via its Nix wrapper (never run it any other way):' \
        --replace-fail 'python3 "''${CLAUDE_SKILL_DIR}/bracket.py"' \
                       '${lib.getExe arenaBracket}' \
        --replace-fail ' If the path looks unexpanded, use the "Base directory for
      this skill" that Claude Code printed at the top of this skill.' ""
      runHook postInstall
    '';

    meta = {
      description = "Single-elimination arena of sub-agents competing on one task";
      homepage = "https://github.com/Jakeschincariol/arena-skill";
      license = lib.licenses.mit;
    };
  };

  # name -> каталог скилла (derivation или путь внутри неё).
  skills = { inherit arena; }
    // import ./brainstorming.nix { inherit lib pkgs; }
    // import ./ui-ux-pro-max.nix { inherit lib pkgs; }
    // import ./emil.nix { inherit lib pkgs; };

  roots = [ ".claude/skills" ".codex/skills" ".gemini/config/skills" ];

  # roots × skills -> { "<root>/<name>" = { source; recursive; }; }
  files = lib.listToAttrs (lib.concatMap (root:
    lib.mapAttrsToList (name: drv:
      lib.nameValuePair "${root}/${name}" {
        source = drv;
        recursive = true;
      }) skills) roots);
in
{
  home.file = files;
}
