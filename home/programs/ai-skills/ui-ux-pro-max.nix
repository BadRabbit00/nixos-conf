# UI/UX Pro Max — семь скиллов дизайна: ui-ux-pro-max (ядро, офлайн-поиск по
# стилям/палитрам/шрифтам), design, design-system, brand, ui-styling, slides,
# banner-design.
# https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (MIT)
#
# Апстрим зовёт скрипты как `python …`, `python3 …`, `node …` — интерпретатор из
# случайного PATH, путь то относительно cwd, то через ${CLAUDE_PLUGIN_ROOT},
# которого нет ни в codex, ни в agy. Здесь у всех скриптов одна точка входа,
# ui-ux-pro-max-run: окружение запинено flake.lock, а исполнять она согласна
# только скрипты из протестированного дерева `scripts`.
{ lib, pkgs }:

let
  src = pkgs.fetchFromGitHub {
    owner = "nextlevelbuilder";
    repo = "ui-ux-pro-max-skill";
    rev = "56ea9cf174ed86786187daa9de0e6247cb0747e4";
    hash = "sha256-77NDhLB84fc2HZKYjdFY5LWjd7C9f21vrCjKdj+ceDU=";
  };

  version = "2.15.0-unstable-2026-10-15";

  names = [ "ui-ux-pro-max" "design" "design-system" "brand" "ui-styling" "slides" "banner-design" ];

  # Ядро — чистый stdlib. google-genai и pillow нужны генераторам логотипов,
  # иконок и CIP в design (ключи — GEMINI_API_KEY/ATLASCLOUD_API_KEY/MUAPI_API_KEY
  # из окружения проекта). node — для .cjs из brand/design-system; оттуда же npx,
  # которым ui-styling ставит shadcn в сам проект.
  python = pkgs.python3.withPackages (ps: [ ps.google-genai ps.pillow ]);

  # Скрипты со своими data/ и соседями: ../design-system, logo/ рядом с cip/ —
  # раскладка .claude/skills сохраняется целиком, тесты гоняются по ней.
  scripts = pkgs.stdenvNoCC.mkDerivation {
    pname = "ui-ux-pro-max-scripts";
    inherit version src;

    # generate-slide.py ищет проект как parents[4] своего файла — верно только
    # для установки в <project>/.claude/skills. Из стора это /nix, поэтому корень
    # берём как соседние скрипты: DESIGN_SYSTEM_PROJECT_ROOT, иначе cwd.
    postPatch = ''
      substituteInPlace .claude/skills/design-system/scripts/generate-slide.py \
        --replace-fail 'import argparse' 'import argparse
      import os' \
        --replace-fail 'Path(__file__).resolve().parents[4]' \
                       'Path(os.environ.get("DESIGN_SYSTEM_PROJECT_ROOT") or Path.cwd()).resolve()'
    '';

    dontConfigure = true;
    dontBuild = true;

    doCheck = true;
    nativeCheckInputs = [ (pkgs.python3.withPackages (ps: [ ps.google-genai ps.pillow ps.pytest ])) pkgs.nodejs ];
    checkPhase = ''
      runHook preCheck
      (cd .claude/skills && pytest -q -p no:cacheprovider .)
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      cp -r .claude/skills "$out"
      find "$out" \( -name tests -o -name __pycache__ -o -name .coverage \) -prune -exec rm -r {} +
      runHook postInstall
    '';
  };

  run = pkgs.writeShellApplication {
    name = "ui-ux-pro-max-run";
    runtimeInputs = [ python pkgs.nodejs pkgs.coreutils ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: ui-ux-pro-max-run <script> [args...]" >&2
        exit 64
      fi
      script=$(realpath -e -- "$1") || exit 66
      shift
      case "$script" in
        ${scripts}/*.py) exec python3 "$script" "$@" ;;
        ${scripts}/*.cjs) exec node "$script" "$@" ;;
        *)
          echo "ui-ux-pro-max-run: only runs scripts under ${scripts}" >&2
          exit 64
          ;;
      esac
    '';
  };

  runExe = lib.getExe run;

  # Документация с путями, переписанными на обёртку и дерево `scripts`.
  # sed, а не substituteInPlace: вызовов около сотни на два десятка файлов,
  # и форма у них одна — интерпретатор, затем путь от скилла или от соседа.
  docs = pkgs.stdenvNoCC.mkDerivation {
    pname = "ui-ux-pro-max-skills";
    inherit version;
    src = scripts;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      chmod -R u+w "$out"
      for skill in ${lib.escapeShellArgs names}; do
        cp ${src}/LICENSE "$out/$skill/LICENSE"
        find "$out/$skill" -name '*.md' -exec sed -E -i \
          -e 's#python3? "\$\{CLAUDE_PLUGIN_ROOT\}/\.claude/skills/#${runExe} "${scripts}/#g' \
          -e 's#(python3?|node) \.\./([a-z-]+)/scripts/#${runExe} ${scripts}/\2/scripts/#g' \
          -e "s#(python3?|node) scripts/#${runExe} ${scripts}/$skill/scripts/#g" \
          -e 's#pip install google-genai( pillow)?#\# google-genai and pillow ship inside ui-ux-pro-max-run; never pip install#g' \
          {} +
      done

      substituteInPlace "$out/ui-ux-pro-max/SKILL.md" \
        --replace-fail 'If `python` is not found, try `python3`, then `py -3`. Requires Python 3.x, no external dependencies (see README for install instructions if Python is missing).' \
                       'The wrapper carries its own pinned Python from Nix; never run search.py with any other interpreter.'
      substituteInPlace "$out/design/SKILL.md" \
        --replace-fail '**Python:** This skill uses Python scripts. On Windows, use `python` instead of `python3` (e.g., `${runExe} ${scripts}/design/scripts/logo/search.py` instead of `${runExe} ${scripts}/design/scripts/logo/search.py`).' \
                       '**Python:** every script runs through `${runExe}`, which carries a pinned Python with google-genai and pillow. Never call the scripts with another interpreter.'

      # Ни одна команда в доках не должна остаться без обёртки.
      if grep -rnE '\b(python3?|node) [^ ]*\.(py|cjs)' "$out" --include='*.md' | grep -v "${runExe}"; then
        echo "unwrapped script invocations left in the docs" >&2
        exit 1
      fi
      runHook postInstall
    '';

    meta = {
      description = "UI/UX Pro Max design skills with a pinned script runner";
      homepage = "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill";
      license = lib.licenses.mit;
    };
  };
in
lib.genAttrs names (name: "${docs}/${name}")
