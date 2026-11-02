# ECC (Everything Claude Code) — операционная система для агентов: сотни скиллов,
# агенты, slash-команды, правила и хук-рантайм на node.
# https://github.com/affaan-m/ecc (MIT); источник — свой форк BadRabbit00/ECC, ветка
# badrabbit (flake-input `ecc`): там же модуль `badrabbit` со своими скиллами,
# как добавить скилл — BADRABBIT.md в форке.
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
# Профиль — ECC `developer` + `security` + `devops-infra` + `badrabbit` (свои
# скиллы): что ставить, решает список `modules` в nix/payload.nix форка по его
# manifests/install-modules.json. Сами деривации (runtime.nix: репозиторий +
# node_modules в сторе, обёртки ecc-run / ecc-hook; payload.nix: выборка по
# модулям, модели агентов, переписанная документация; nix-first.md,
# ECC-GUIDE.md) живут в форке, каталог nix/. Здесь только раскладка по агентам
# и слияние хуков/ролей в их конфиги.
#
# Флейвор (ai.ecc.flavour), контракт описан в BADRABBIT.md форка:
#   legacy  payload.nix: ECC целиком, rules/ecc, хуки ecc-hook, ecc-guide.md;
#   br      payload-br.nix (badrabbit/): свой CLAUDE.md-ядро, стиль orchestrator,
#           24 изолированных агента, rules/br, хуки br-hook, br/bin/br-risk (калькулятор
#           карты рисков, вызывается по пути, не из PATH); settings.fragment.json
#           (env + outputStyle) вливается в settings.json. rules/ecc не ставится.
# codex и agy пока всегда получают legacy-payload: у br экспорта для них нет.
{ config, lib, pkgs, inputs, ... }:

let
  ai = import ../lib.nix { inherit lib pkgs; };
  cfg = config.ai.ecc;
  isBr = cfg.flavour == "br";
  # Деривации собирает сам форк (inputs.ecc.lib.mk); тот же вызов в профиле
  # security даёт ту же деривацию.
  ecc = inputs.ecc.lib.mk { inherit pkgs lib; };
  inherit (ecc) payload payloadBr run hook brHook;
  claudePayload = if isBr then payloadBr else payload;

  # settings.fragment.json br-флейвора; при legacy снимаем ровно те значения,
  # которые он туда положил, чтобы откат не оставлял orchestrator-стиль.
  # Читаем из исходников форка, не из выхода payload: без IFD.
  brSettings = lib.importJSON (inputs.ecc + "/badrabbit/settings.fragment.json");
  settingsExpr =
    if isBr then ". * $ours[0]"
    else lib.concatStringsSep " | " (
      lib.mapAttrsToList (k: v: ''if .env.${k} == ${builtins.toJSON v} then del(.env.${k}) else . end'') brSettings.env
      ++ [ ''if .outputStyle == ${builtins.toJSON brSettings.outputStyle} then del(.outputStyle) else . end'' ]);

  # --- Слияние с мутабельными конфигами агентов --------------------------------
  # settings.json claude пишет сам (autoMode, modelSettings…), config.toml codex
  # тоже (trust_level). Не владеем — вливаем свой кусок по ключу.
  sync = pkgs.writeShellApplication {
    name = "ecc-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      # Свои записи узнаём по id (ставит ECC) или по команде ecc-hook/br-hook
      # (сторовый путь меняется с каждым ребилдом); чужие хуки остаются как были.
      # Смена флейвора так же вычищает хуки другого флейвора.
      ${ai.mergeJson { file = ''"$HOME/${ai.roots.claude}/settings.json"''; frag = "${claudePayload}/hooks.json"; expr = ''
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
                      | select(([.hooks[]?.command // ""] | any(test("/bin/(ecc|br)-hook "))) | not)
                    ]
                    + ($new[$ev] // [])
                  )
              )
            | with_entries(select(.value != []))
          )''; }}
      ${ai.mergeJson { file = ''"$HOME/${ai.roots.claude}/settings.json"''; frag = "${payloadBr}/settings.fragment.json"; expr = settingsExpr; }}
      # Codex: multi_agent и роли explorer/reviewer/docs_researcher из ECC
      # (config_file относителен CODEX_HOME -> ~/.codex/agents/*.toml ниже).
      # Существующие ключи пользователя сильнее наших.
      ${ai.mergeToml { file = ''"$HOME/${ai.roots.codex}/config.toml"''; frag = codexFrag; expr = ''
        .features = ($ours[0].features + (.features // {}))
        | .agents = ($ours[0].agents + (.agents // {}))''; }}
      echo "ECC (${cfg.flavour}): хуки и настройки влиты в ~/.claude/settings.json, роли агентов — в ~/.codex/config.toml"
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
  options.ai.ecc = {
    flavour = lib.mkOption {
      type = lib.types.enum [ "legacy" "br" ];
      default = "br";
      description = "Какой payload форка ECC раскладывать в ~/.claude: legacy (payload.nix) или br (badrabbit/).";
    };
    core = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      readOnly = true;
      default = if isBr then "${payloadBr}/claude/CLAUDE.md" else null;
      description = "Ядро CLAUDE.md флейвора br (null для legacy); профиль code склеивает его со своей персоной.";
    };
  };

  config = {
    home.packages = [ run sync ] ++ (if isBr then [ brHook ] else [ hook ]);

    # Плоская раскладка, как у ручного инсталлятора ECC. recursive: каталоги
    # настоящие, файлы — симлинки в стор, соседние скиллы из ../skills не трогаем.
    home.file = {
      "${roots.claude}/skills"    = recursive "${claudePayload}/claude/skills";
      "${roots.claude}/agents"    = recursive "${claudePayload}/claude/agents";
      "${roots.claude}/commands"  = recursive "${claudePayload}/claude/commands";
      # codex не видит скилл с SKILL.md-симлинком: каждый скилл — симлинк на каталог.
      "${roots.codex}/skills"     = recursive (ai.dirLinks "ecc-codex-skills" "${payload}/codex/skills");
      "${roots.codex}/prompts"    = recursive "${payload}/codex/prompts";
      "${roots.codex}/agents"     = recursive "${payload}/codex/agents";
      "${roots.codex}/AGENTS.md".source = "${payload}/codex/AGENTS.md";
      "${roots.agy}/agents"       = recursive "${payload}/agy/agents";
    } // (if isBr then {
      "${roots.claude}/rules/br"      = recursive "${payloadBr}/claude/rules/br";
      "${roots.claude}/output-styles" = recursive "${payloadBr}/claude/output-styles";
      "${roots.claude}/br/templates"  = recursive "${payloadBr}/claude/br/templates";
      # br-risk зовут по пути ~/.claude/br/bin/br-risk (оркестратор и скилл risk-model),
      # поэтому в home.packages его нет; recursive кладёт симлинк на сторовый бинарь как есть.
      "${roots.claude}/br/bin"        = recursive "${payloadBr}/claude/br/bin";
    } else {
      "${roots.claude}/rules/ecc" = recursive "${payload}/claude/rules/ecc";
      # Гайд по всем командам: claude подтягивает его из ~/.claude/CLAUDE.md
      # через `@~/.claude/ecc-guide.md` (profiles/code/ecc-legacy.md), codex —
      # внутри AGENTS.md выше.
      "${roots.claude}/ecc-guide.md".source = "${payload}/ECC-GUIDE.md";
    });

    home.activation.eccSync =
      lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/ecc-sync";
  };
}
