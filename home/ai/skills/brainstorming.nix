# brainstorming — выяснить, что на самом деле нужно, до того как что-то строить.
# https://github.com/obra/superpowers/tree/main/skills/brainstorming (MIT)
#
# Визуальный компаньон — node-сервер (server.cjs), который апстрим запускает через
# `bash scripts/start-server.sh` с `node` из случайного PATH. Здесь обе точки
# входа — обёртки с окружением из runtimeInputs; скрипты исполняются прямо из
# исходника, где лежит package.json, из которого сервер читает свою версию.
{ lib, pkgs }:

let
  src = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "bb92a77741419a4ab5f06e711a283343f1ada0c3";
    hash = "sha256-UCVI+T7j1Xh1LDkrvnJduis7eHFqrizCyGTWAGW5d6U=";
  };

  scripts = "${src}/skills/brainstorming/scripts";

  # start-server.sh: bash, nohup/od/date, ps (PID агента-владельца), grep по логу;
  # xdg-open — для --open.
  serverInputs = with pkgs; [ bash nodejs coreutils procps gnugrep xdg-utils ];

  # exec обязателен: start-server.sh берёт владельца как родителя своего $PPID,
  # лишний уровень процесса сделал бы владельцем короткоживущую обёртку.
  # Без телеметрии страница не тянет логотип с primeradiant.com при каждом показе.
  start = pkgs.writeShellApplication {
    name = "brainstorm-start";
    runtimeInputs = serverInputs;
    text = ''
      export SUPERPOWERS_DISABLE_TELEMETRY=1
      exec bash ${scripts}/start-server.sh "$@"
    '';
  };

  stop = pkgs.writeShellApplication {
    name = "brainstorm-stop";
    runtimeInputs = serverInputs;
    text = ''exec bash ${scripts}/stop-server.sh "$@"'';
  };

  # Единственная npm-зависимость тестов (ws) — из их же package-lock.json,
  # с проверкой integrity и без сети в сборке.
  testModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = "${src}/tests/brainstorm-server";
    inherit (pkgs) nodejs;
  };
in
{
  brainstorming = pkgs.stdenvNoCC.mkDerivation {
    pname = "brainstorming-skill";
    version = "7.0.0-unstable-2026-10-09";
    inherit src;

    dontConfigure = true;
    dontBuild = true;

    doCheck = true;
    nativeCheckInputs = serverInputs ++ [ pkgs.perl ];
    checkPhase = ''
      runHook preCheck
      patchShebangs --build skills/brainstorming/scripts tests/brainstorm-server
      # Самозванцев с чужим argv[0] тест делает через `exec -a … sleep`, а sleep
      # из nixpkgs — симлинк на multicall-coreutils, который по argv[0] и
      # выбирает утилиту. perl на argv[0] плевать — проверка остаётся той же.
      substituteInPlace tests/brainstorm-server/stop-server.test.sh \
        --replace-fail '" sleep 600 ) &' '" perl -e "sleep 600" ) &'
      cd tests/brainstorm-server
      ln -s ${testModules}/node_modules node_modules
      for t in ws-protocol helper browser-launcher auth branding server lifecycle; do
        node "$t.test.js"
      done
      # start-server.test.sh не гоняем: он проверяет только Windows-детект через
      # фейковые uname/node с `#!/usr/bin/env bash`, которого в песочнице нет, и
      # вместо фейка запускает настоящий сервер, висящий до таймаута.
      bash stop-server.test.sh
      cd -
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      cp -r skills/brainstorming "$out"
      chmod -R u+w "$out"
      cp LICENSE "$out/LICENSE"
      # Сервер и его запуск — только через обёртки; шаблон и helper.js остаются
      # справочником по CSS-классам, на который ссылается visual-companion.md.
      rm "$out"/scripts/{server.cjs,start-server.sh,stop-server.sh}

      substituteInPlace "$out/SKILL.md" \
        --replace-fail 'a full plan (for software: superpowers:writing-plans)' \
                       'a full implementation plan' \
        --replace-fail 'the next step is the plan. For
      software, invoke superpowers:writing-plans and no other skill.' \
                       'the next step is the plan: write the
      implementation plan before any code.'

      substituteInPlace "$out/visual-companion.md" \
        --replace-fail 'bash scripts/start-server.sh' '${lib.getExe start}' \
        --replace-fail 'bash scripts/stop-server.sh' '${lib.getExe stop}' \
        --replace-fail 'restart it with `start-server.sh`' \
                       'restart it with `${lib.getExe start}`'
      runHook postInstall
    '';

    meta = {
      description = "Superpowers brainstorming skill with its visual companion server";
      homepage = "https://github.com/obra/superpowers/tree/main/skills/brainstorming";
      license = lib.licenses.mit;
    };
  };
}
