# Jammerflow

## Config Files

- `config.example.toml` is a template for public distribution. Do NOT edit it for runtime changes.
- The active config is at `~/projects/dotfiles.v2/jammerflow/config.toml`, which is symlinked into `~/.hammerspoon/Spoons/Hammerflow.spoon/config.toml`.
- When making config changes (adding backgrounds, keybindings, submenus, etc.), always edit the active config at `~/projects/dotfiles.v2/jammerflow/config.toml`, not `config.example.toml`.

## Images

- New icons should be added to `~/projects/dotfiles.v2/jammerflow/images/icons/` and backgrounds to `~/projects/dotfiles.v2/jammerflow/images/backgrounds/`.
- The `images/` directory in this repo is symlinked from `~/projects/dotfiles.v2/jammerflow/images/`.
- In config and Lua code, reference icons as `icons/filename.png` and backgrounds as `backgrounds/filename.gif`.
