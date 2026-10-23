> **NixOS environment (local adaptation of this skill).** This machine is NixOS
> and everything is declarative. Before following any command below:
> - `ffmpeg`, `ffprobe`, `python3` (with numpy, opencv, pillow, scipy, librosa), `node`,
>   `manim`, `remotion`, `hyperframes`, `apify`, `whisper-cli`, `piper`, `sox`,
>   `magick`, `yt-dlp`, `mediainfo` and the other tools this profile needs are already
>   on PATH inside `claude-montage` — use them directly, do not install anything.
> - Anything else: one-off via `nix shell nixpkgs#<pkg> -c <cmd>`; find packages
>   with `nix search nixpkgs <name>`. Never `pip install`, `npm install -g`,
>   `uv tool install`, `brew`, `apt`, `curl | sh`. If a script really needs a
>   missing library, say so instead of installing it — it has to be added to
>   `home/ai/profiles/montage` in `~/nixos-conf`.
> - No inline interpreters (`python -c`, `node -e`, long `bash -c`): write a
>   script file and run it.
> - Skill scripts live in `~/.claude-montage/skills/<skill>/…` (read-only store
>   symlinks): run them from there with absolute paths, write outputs elsewhere.
> - Video editing itself happens in FilmCraft / EffectCraft (storytold), not in
>   Premiere or DaVinci Resolve — translate node/panel advice accordingly.
