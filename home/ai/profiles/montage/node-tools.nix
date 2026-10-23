# CLI-инструменты из npm для профиля montage: Remotion (видео из React/TS),
# HyperFrames (видео из HTML, рендер детерминированный по кадрам) и Apify
# (скрейпинг/акторы). В nixpkgs их нет, поэтому — тот же приём, что у ECC:
# package.json + package-lock.json лежат в репо, importNpmLock собирает
# node_modules в сторе, наружу торчат только обёртки.
#
# Браузер для рендера — chromium из Nix, а не скачанный в ~/.cache:
#   hyperframes читает HYPERFRAMES_BROWSER_PATH (первым, до puppeteer-кэша);
#   remotion принимает только флаг --browser-executable, обёртка подставляет
#   его командам, которые рендерят.
# Лок обновляется так: nix shell nixpkgs#nodejs -c npm install
#   --package-lock-only --ignore-scripts в этом каталоге, после правки версий.
{ lib, pkgs }:

let
  nodejs = pkgs.nodejs;
  src = ./node-tools;
  packageJson = lib.importJSON "${src}/package.json";

  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = src;
    inherit nodejs;
    derivationArgs = {
      pname = "montage-node-tools";
      inherit (packageJson) version;
    };
  };
  nm = "${nodeModules}/node_modules";
  chromium = lib.getExe pkgs.chromium;

  hyperframes = pkgs.writeShellApplication {
    name = "hyperframes";
    runtimeInputs = [ nodejs pkgs.ffmpeg-full ];
    text = ''
      export HYPERFRAMES_BROWSER_PATH="''${HYPERFRAMES_BROWSER_PATH:-${chromium}}"
      export PUPPETEER_SKIP_DOWNLOAD=1
      exec node ${nm}/hyperframes/bin/hyperframes.mjs "$@"
    '';
  };

  remotion = pkgs.writeShellApplication {
    name = "remotion";
    runtimeInputs = [ nodejs ];
    text = ''
      # Рендер-команды получают chromium из Nix, если путь не задан явно.
      case "''${1:-}" in
        render|still|compositions|benchmark)
          case " $* " in
            *" --browser-executable"*) ;;
            *) set -- "$1" --browser-executable="${chromium}" "''${@:2}" ;;
          esac ;;
      esac
      exec node ${nm}/@remotion/cli/remotion-cli.js "$@"
    '';
  };

  apify = pkgs.writeShellApplication {
    name = "apify";
    runtimeInputs = [ nodejs ];
    text = ''exec node ${nm}/apify-cli/dist/apify.js "$@"'';
  };
in
{
  inherit nodeModules hyperframes remotion apify;
  all = [ hyperframes remotion apify ];
}
