# ECC (Everything Claude Code) — операционная система для агентов: 311 скиллов,
# 71 агент, 97 slash-команд, правила и хук-рантайм на node.
# https://github.com/affaan-m/ecc (MIT)
#
# Апстрим ставится через `npx ecc-universal setup` или `/plugin install`, которые
# копируют репозиторий в ~/.claude/plugins и зовут `node` из случайного PATH.
# Здесь всё иначе:
#   - репозиторий целиком лежит в /nix/store (`root`) вместе с node_modules из
#     package-lock.json; хуки читают его как read-only CLAUDE_PLUGIN_ROOT —
#     состояние они пишут в ~/.claude, ~/.gateguard, ~/.local/share;
#   - у скриптов две точки входа: `ecc-hook` (хуки Claude Code) и `ecc-run`
#     (скрипты скиллов/команд), обе с запиненным node/python/bash/git;
#   - документация переписана: `node scripts/x.js`, `python3 …/instinct-cli.py`,
#     `~/.claude/skills/<skill>/…` ведут в стор через ecc-run, а в каждый
#     SKILL.md / command / rules вшит баннер про Nix-доктрину (devShell,
#     nix shell, dockerTools, никаких pip/npm -g/brew);
#   - раскладка повторяет ручной инсталлятор ECC (install-apply.js): скиллы
#     плоско в ~/.claude/skills и ~/.codex/skills, агенты в ~/.claude/agents,
#     команды в ~/.claude/commands, правила в ~/.claude/rules/ecc, для codex —
#     AGENTS.md, prompts и роли агентов;
#   - хуки вливаются в ~/.claude/settings.json activation-скриптом по id, как
#     ai-mcp-sync вливает MCP: файл мутабельный, владеть им через home.file нельзя.
#
# Профиль — ECC `developer` + `security` + `devops-infra`: что ставить, решает
# список `modules` в payload.nix по апстримному manifests/install-modules.json, а не
# ручной перечень из 300 имён.
# Файлы модуля:
#   runtime.nix  репозиторий + node_modules в сторе, обёртки ecc-run / ecc-hook
#   payload.nix  выборка по модулям, модели агентов, переписанная документация
#   default.nix  раскладка по агентам и слияние хуков/ролей в их конфиги
{ lib, pkgs, ... }:

let
  ai = import ../lib.nix { inherit lib pkgs; };
  runtime = import ./runtime.nix { inherit lib pkgs; };
  payload = import ./payload.nix { inherit lib pkgs runtime; };
  inherit (runtime) run hook;

  # --- Слияние с мутабельными конфигами агентов --------------------------------
  # settings.json claude пишет сам (autoMode, modelSettings…), config.toml codex
  # тоже (trust_level). Не владеем — вливаем свой кусок по ключу.
  sync = pkgs.writeShellApplication {
    name = "ecc-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      # Свои записи узнаём по id (ставит ECC) или по команде ecc-hook (сторовый
      # путь меняется с каждым ребилдом); чужие хуки остаются как были.
      ${ai.mergeJson { file = ''"$HOME/${ai.roots.claude}/settings.json"''; frag = "${payload}/hooks.json"; expr = ''
        ($ours[0].hooks) as $new
        | (.hooks // {}) as $old
        | .hooks = (
            ($old + $new)
            | with_entries(
                .key as $ev
                | .value = (
                    [ ($old[$ev] // [])[]
                      | select((.id // "") as $id
                               | ($new[$ev] // [] | map(.id) | index($id)) == null)
                      | select(([.hooks[]?.command // ""] | any(test("/bin/ecc-hook "))) | not)
                    ]
                    + ($new[$ev] // [])
                  )
              )
          )''; }}
      # Codex: multi_agent и роли explorer/reviewer/docs_researcher из ECC
      # (config_file относителен CODEX_HOME -> ~/.codex/agents/*.toml ниже).
      # Существующие ключи пользователя сильнее наших.
      ${ai.mergeToml { file = ''"$HOME/${ai.roots.codex}/config.toml"''; frag = codexFrag; expr = ''
        .features = ($ours[0].features + (.features // {}))
        | .agents = ($ours[0].agents + (.agents // {}))''; }}
      echo "ECC: хуки влиты в ~/.claude/settings.json, роли агентов — в ~/.codex/config.toml"
    '';
  };

  codexFrag = (pkgs.formats.json { }).generate "ecc-codex.json" {
    features.multi_agent = true;
    agents = {
      max_threads = 6;
      max_depth = 1;
      explorer = {
        description = "Read-only codebase explorer for gathering evidence before changes are proposed.";
        config_file = "agents/explorer.toml";
      };
      reviewer = {
        description = "PR reviewer focused on correctness, security, and missing tests.";
        config_file = "agents/reviewer.toml";
      };
      docs_researcher = {
        description = "Documentation specialist that verifies APIs, framework behavior, and release notes.";
        config_file = "agents/docs-researcher.toml";
      };
    };
  };

  inherit (ai) recursive roots;
in
{
  home.packages = [ run hook sync ];

  # Плоская раскладка, как у ручного инсталлятора ECC. recursive: каталоги
  # настоящие, файлы — симлинки в стор, соседние скиллы из ../skills не трогаем.
  home.file = {
    "${roots.claude}/skills"    = recursive "${payload}/claude/skills";
    "${roots.claude}/agents"    = recursive "${payload}/claude/agents";
    "${roots.claude}/commands"  = recursive "${payload}/claude/commands";
    "${roots.claude}/rules/ecc" = recursive "${payload}/claude/rules/ecc";
    "${roots.codex}/skills"     = recursive "${payload}/codex/skills";
    "${roots.codex}/prompts"    = recursive "${payload}/codex/prompts";
    "${roots.codex}/agents"     = recursive "${payload}/codex/agents";
    "${roots.codex}/AGENTS.md".source = "${payload}/codex/AGENTS.md";
    "${roots.agy}/agents"       = recursive "${payload}/agy/agents";
    # Гайд по всем командам: claude подтягивает его из ~/.claude/CLAUDE.md
    # через `@~/.claude/ecc-guide.md`, codex — внутри AGENTS.md выше.
    "${roots.claude}/ecc-guide.md".source = ./ECC-GUIDE.md;
  };

  home.activation.eccSync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/ecc-sync";
}
