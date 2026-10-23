# devShell montage-ml: тяжёлый ML для монтажа, который не должен жить в PATH
# агента. Вход: `nix develop ~/nixos-conf#montage-ml` (или direnv в проекте).
#
#   whisperx        транскрипция с пословными таймкодами и диаризацией (CUDA)
#   faster-whisper  быстрая транскрипция на CTranslate2 (CUDA)
#   uv              для ACE-Step 1.5 (claude-music): движок живёт в своём
#                   checkout и ставит зависимости через `uv run` в собственный
#                   venv внутри каталога; сюда он не пинится — отдельная задача
#                   (uv2nix по его uv.lock, как colab-mcp). ACE_STEP_DIR указывает
#                   на checkout; скилл claude-music читает его из config.json.
#
# Торч и CUDA приходят из cache.nixos-cuda.org (pkgs собран с cudaSupport = true).
{ pkgs }:

let
  python = pkgs.python3.withPackages (ps: with ps; [ faster-whisper whisperx torch torchaudio ]);
in
pkgs.mkShell {
  name = "montage-ml";
  packages = [ python pkgs.uv pkgs.ffmpeg-full pkgs.cudaPackages.cudatoolkit ];
  shellHook = ''
    export ACE_STEP_DIR="''${ACE_STEP_DIR:-$HOME/src/ACE-Step-1.5}"
    # uv не должен тянуть свой python: интерпретатор и CUDA-рантайм берём из Nix.
    export UV_PYTHON="${python}/bin/python3"
    export UV_PYTHON_DOWNLOADS=never
    # Бинарные колёса из PyPI (torch в ACE-Step) ищут libstdc++, zlib и libcuda
    # через загрузчик; на NixOS их даём явно, драйвер — из /run/opengl-driver.
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib ]}:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "montage-ml: whisperx, faster-whisper, uv; ACE_STEP_DIR=$ACE_STEP_DIR"
  '';
}
