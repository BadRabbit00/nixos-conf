# warren (br) — слой агентов из отдельного репозитория BadRabbit00/warren, ветка
# develop (flake-input `warren`): оркестратор-стиль, изолированные субагенты,
# скиллы, команды, workflows, правила rules/br и хуки br-hook. Вся упаковка
# (nix/payload.nix, br-hook) живёт в warren; здесь только раскладка по домам
# агентов и слияние хуков/настроек/ролей в их мутабельные конфиги.
#
# Раскладка:
#   ~/.claude  agents, skills, commands, workflows, rules/br, output-styles, br/templates
#   ~/.codex   agents, prompts, skills (симлинки на каталоги), AGENTS.md
#   agy        agents (корень roots.agy = ~/.gemini/config, как в README warren)
# settings.json (claude) и config.toml (codex) агенты пишут сами, поэтому не
# владеем ими через home.file, а вливаем свой кусок activation-скриптом.
{ config, lib, pkgs, inputs, ... }:

let
  ai = import ../lib.nix { inherit lib pkgs; };
  warren = inputs.warren.lib.mk { inherit pkgs; };
  inherit (warren) payload hook;
  inherit (ai) recursive roots;

  # agents.toml warren -> JSON: mergeToml берёт фрагмент через jq --slurpfile.
  codexFrag = pkgs.runCommand "warren-codex-agents.json" { nativeBuildInputs = [ pkgs.remarshal ]; } ''
    remarshal -if toml -of json < ${payload}/codex/agents.toml > "$out"
  '';

  sync = pkgs.writeShellApplication {
    name = "warren-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      # Свои хуки узнаём по id; записи с командой /bin/(ecc|br)-hook, которых нет
      # в текущем hooks.json (сторовый путь меняется с каждым ребилдом, а старые
      # ECC-хуки больше не существуют), вычищаются. Чужие хуки остаются.
      ${ai.mergeJson { file = ''"$HOME/${roots.claude}/settings.json"''; frag = "${payload}/hooks.json"; expr = ''
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
      # env + outputStyle: значения warren сильнее, остальное в settings.json остаётся.
      ${ai.mergeJson { file = ''"$HOME/${roots.claude}/settings.json"''; frag = "${payload}/settings.fragment.json"; expr = ". * $ours[0]"; }}
      # Codex: роли агентов warren (config_file относителен CODEX_HOME ->
      # ~/.codex/agents/*.toml ниже). Существующие ключи пользователя сильнее.
      ${ai.mergeToml { file = ''"$HOME/${roots.codex}/config.toml"''; frag = codexFrag; expr = ''
        .agents = ($ours[0].agents + (.agents // {}))''; }}
      echo "warren: хуки и настройки влиты в ~/.claude/settings.json, роли агентов — в ~/.codex/config.toml"
    '';
  };
in
{
  options.ai.warren.core = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    default = "${payload}/claude/CLAUDE.md";
    description = "Ядро CLAUDE.md из warren; профиль code склеивает его со своей персоной.";
  };

  config = {
    home.packages = [ hook sync ];

    # recursive: каталоги настоящие, файлы — симлинки в стор, соседние скиллы
    # из ../skills не трогаем.
    home.file = {
      "${roots.claude}/skills"        = recursive "${payload}/claude/skills";
      "${roots.claude}/agents"        = recursive "${payload}/claude/agents";
      "${roots.claude}/commands"      = recursive "${payload}/claude/commands";
      "${roots.claude}/workflows"     = recursive "${payload}/claude/workflows";
      "${roots.claude}/rules/br"      = recursive "${payload}/claude/rules/br";
      "${roots.claude}/output-styles" = recursive "${payload}/claude/output-styles";
      "${roots.claude}/br/templates"  = recursive "${payload}/claude/br/templates";
      # codex не видит скилл с SKILL.md-симлинком: каждый скилл — симлинк на каталог.
      "${roots.codex}/skills"         = recursive (ai.dirLinks "warren-codex-skills" "${payload}/codex/skills");
      "${roots.codex}/prompts"        = recursive "${payload}/codex/prompts";
      "${roots.codex}/agents"         = recursive "${payload}/codex/agents";
      "${roots.codex}/AGENTS.md".source = "${payload}/codex/AGENTS.md";
      "${roots.agy}/agents"           = recursive "${payload}/agy/agents";
    };

    home.activation.warrenSync =
      lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/warren-sync";
  };
}
