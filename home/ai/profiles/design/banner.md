> **NixOS environment (local adaptation of this skill).** This machine is NixOS
> and everything is declarative. Before following any command below:
> - `magick` (ImageMagick), `inkscape`, `potrace`, `python3` (with pillow, numpy,
>   opencv, scikit-image, playwright), `chromium` and `node` are already on PATH
>   inside `claude-design` — use them directly, do not install anything.
> - Anything else: one-off via `nix shell nixpkgs#<pkg> -c <cmd>`; find packages
>   with `nix search nixpkgs <name>`. Never use pip, global npm, uv tool, brew,
>   apt or piped shell installers. If a script really needs a missing library,
>   say so instead of installing it — it has to be added to
>   `home/ai/profiles/design` in `~/nixos-conf`.
> - No inline interpreters (`python -c`, `node -e`, long `bash -c`): write a
>   script file and run it.
> - Skill files live in `~/.claude-design/skills/<skill>/…` (read-only store
>   symlinks): run scripts from there with absolute paths, write outputs elsewhere.
> - The user is a designer, not a developer: answer in Russian, explain results
>   in design terms (pixels, ratios, colours), keep tool output out of the way.
