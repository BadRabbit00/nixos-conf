# unslop — вычистка «ИИ-слопа» из текста: rewrite/cleanup/mimic, голосовые
# профили и набор сканеров на чистом stdlib-python.
# https://github.com/theclaymethod/unslop (MIT)
{ lib, pkgs }:

let
  # rev, а не тег: апстрим тегов не ставит, версия — из frontmatter SKILL.md.
  src = pkgs.fetchFromGitHub {
    owner = "theclaymethod";
    repo = "unslop";
    rev = "17ed39c9d0b522f44190ff0c6233867eadee192a";
    hash = "sha256-M/w0ASIxhBmcSS2eNOh92IRb5hJg1cugLoCLbsC34Oo=";
  };

  # Апстрим зовёт `python3 scripts/<name>.py` относительно каталога скилла:
  # интерпретатор из случайного PATH и зависимость от cwd. Единственная точка
  # входа — обёртка `unslop-py <name>` (расширение .py необязательно) с python3
  # из runtimeInputs; `unslop-py evals/<name>` запускает скрипт из evals/.
  # Скрипты берутся из src, а не из каталога скилла: обёртка не должна зависеть
  # от результата сборки (иначе круг: доки зовут обёртку, обёртка — скилл).
  # Тот же src держит evals/ (фикстуры для silhouette_scan и voice_score,
  # evals/run_mimic_refine.py) — в сам скилл он не попадает.
  # -E вместо -I: -I убрал бы каталог скрипта из sys.path, а скрипты
  # импортируют друг друга как соседей.
  unslopPy = pkgs.writeShellApplication {
    name = "unslop-py";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      name="''${1:?usage: unslop-py [evals/]<script> [args...]}"
      shift
      name="''${name%.py}"
      dir=scripts
      case "$name" in evals/*) dir=evals; name="''${name#evals/}" ;; esac
      case "$name" in */* | "" | .* | _*) echo "unslop-py: bad script name: $name" >&2; exit 64 ;; esac
      script="${src}/$dir/$name.py"
      [ -f "$script" ] || { echo "unslop-py: no such script: $dir/$name" >&2; exit 64; }
      # -B: стор read-only, __pycache__ туда всё равно не лечь.
      exec python3 -B -E "$script" "$@"
    '';
  };

  wrapper = lib.getExe unslopPy;

  skill = pkgs.stdenvNoCC.mkDerivation {
    pname = "unslop-skill";
    version = "2.3.0";
    inherit src;

    dontConfigure = true;
    dontBuild = true;

    # У апстрима есть evals/check.py и check_*.py, но его CI ставит
    # skill-benchmark через pipx из git — набор не герметичен, здесь его не
    # гоняем. Вместо него: скрипты компилируются и сканеры отрабатывают без
    # traceback на том же python3, что сидит в обёртке. Код 1 сканера на
    # «грязном» тексте — норма; всё выше 1 (traceback, 2, 64) — падение.
    doCheck = true;
    nativeCheckInputs = [
      pkgs.python3
      unslopPy
    ];
    checkPhase = ''
      runHook preCheck
      # Кэш байткода мимо исходников.
      export PYTHONPYCACHEPREFIX="$TMPDIR/pyc"
      python3 -m py_compile scripts/*.py

      noTraceback() {
        local out
        out="$("$@" 2>&1)" || true
        if grep -q Traceback <<<"$out"; then
          echo "traceback in: $*" >&2
          echo "$out" >&2
          return 1
        fi
      }

      # --help есть не у всех: diff_check, validate_preservation, check_packs и
      # refresh_status argparse не используют.
      for f in scripts/*.py; do
        n="$(basename "$f" .py)"
        grep -q argparse "$f" || continue
        noTraceback unslop-py "$n" --help </dev/null
      done
      noTraceback unslop-py evals/run_mimic_refine --help </dev/null

      # Три прозаических абзаца: меньше silhouette_scan не считает и не
      # открывает референс из evals/fixtures/silhouette.
      sample="Here's the thing: in today's fast-paced landscape, let that sink in. The market is evolving rapidly, and businesses must adapt.

      It's not just about speed, it's about unlocking the full potential of your team. Moreover, a robust and seamless approach delivers value.

      In conclusion, the future is bright. Ultimately, we must navigate the complexities of this ever-changing world together."
      for n in banned_phrase_scan structure_scan silhouette_scan readability_metrics; do
        rc=0
        unslop-py "$n" <<<"$sample" >/dev/null || rc=$?
        if [ "$rc" -gt 1 ]; then
          echo "unslop-py $n exited $rc" >&2
          exit 1
        fi
      done
      # Сканер должен отдавать валидный JSON — на него опираются доки.
      json="$(unslop-py banned_phrase_scan <<<"$sample" || true)"
      python3 -m json.tool <<<"$json" >/dev/null
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      # scripts/ не копируем: агент ходит только через обёртку.
      cp -r SKILL.md references presets assets "$out/"
      chmod -R u+w "$out"

      # Апстрим не кладёт LICENSE (README: «Licensed MIT»); текст лицензии не
      # выдумываем — она описана в meta.license.
      [ ! -e LICENSE ] || cp LICENSE "$out/LICENSE"

      # Доки зовут только обёртку. Абсолютный путь — как у arena: agy и codex
      # не знают ни CLAUDE_SKILL_DIR, ни нашего PATH.
      # Четыре файла контрибьютор-/мейнтейнер-флоу не переписываем: они пишут
      # в корень репозитория (.unslop/contrib, .wiki_sync_state.json), а стор
      # read-only — этот флоу идёт из git clone апстрима.
      find "$out" -name '*.md' \
        ! -path '*/references/commands/contribute.md' \
        ! -path '*/references/contribute.md' \
        ! -path '*/references/maintenance.md' \
        ! -path '*/references/refresh.md' \
        -exec sed -i -E \
          -e 's#python3 scripts/([A-Za-z0-9_]+)\.py#${wrapper} \1#g' \
          -e 's#python3 (evals/[A-Za-z0-9_]+)\.py#${wrapper} \1#g' \
          -e 's#`evals/([a-z_]+)\.py`#`${wrapper} evals/\1`#g' {} +
      substituteInPlace "$out/references/mimic.md" \
        --replace-fail '`scripts/voice_profile.py samples/' '`${wrapper} voice_profile samples/' \
        --replace-fail '`scripts/voice_card.py --profile' '`${wrapper} voice_card --profile'
      substituteInPlace "$out/references/commands/teach.md" \
        --replace-fail '`scripts/voice_score.py`' '`${wrapper} voice_score`'
      # voice_score требует --impostors, а evals/ в скилле нет — путь в src.
      substituteInPlace "$out/references/commands/mimic.md" \
        --replace-fail '--impostors evals/fixtures/voice/impostors' \
                       '--impostors ${src}/evals/fixtures/voice/impostors'
      sed -i '1i > Packaged skill note: this flow runs from a `git clone` of upstream, not from the packaged (read-only) skill.' \
        "$out/references/commands/contribute.md"

      # Сторожа: ни вызовов python3 scripts|evals, ни флага с путём evals/ мимо
      # обёртки. Прозаические упоминания evals/... в доках допустимы.
      if grep -rnE --include='*.md' \
          --exclude=contribute.md --exclude=maintenance.md --exclude=refresh.md \
          'python3 (scripts|evals)/|[[:space:]]--[a-z-]+ evals/' "$out"; then
        echo "unrewritten script/evals call left in the docs" >&2
        exit 1
      fi
      runHook postInstall
    '';

    meta = {
      description = "Agent skill that removes AI-writing tells from text and mimics a voice";
      homepage = "https://github.com/theclaymethod/unslop";
      license = lib.licenses.mit;
    };
  };
in
{
  unslop = skill;
}
