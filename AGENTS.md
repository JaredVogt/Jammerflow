# Repository Guidelines

## Project Structure & Module Organization
Jammerflow loads from `init.lua` at the repo root, with configuration defaults in `config.toml` and schema helpers in `toml_validator.lua`. UI modules live in `DynamicMenu/` (runtime menu renderer) and `RecursiveBinder/` (leader-key spoon overrides). Add dynamic menu sources under `DynamicMenu/generators/` using one file per feature (for example `git.lua`). Reference `examples/` for minimal configs and `images/` for shipped assets; keep large binaries out of version control. Use `config-editor.html` only for the visual editor prototype and store supporting docs in the existing `*.md` guides. Note: The Hammerspoon spoon is named `Hammerflow.spoon` for compatibility.

## Build, Test, and Development Commands
Symlink the repo into Hammerspoon before iterating: `ln -s "$(pwd)" ~/.hammerspoon/Spoons/Hammerflow.spoon`. Reload the environment via the Hammerspoon console or CLI: `hs -c "hs.reload()"`. Run TOML validation without a full reload by executing `hs -c "local validate = dofile(hs.configdir .. '/Hammerflow/toml_validator.lua'); validate(hs.configdir .. '/Hammerflow/config.toml', true)"`. When iterating on dynamic menus, call `hs -c "return require('Hammerflow.DynamicMenu').debug('cursor')"` to inspect generator output.

## Coding Style & Naming Conventions
Lua modules use four-space indentation and UTF-8 strings only when required for UI glyphs. Prefer `camelCase` for Lua functions and `snake_case` for local variables; keep exported tables on the `obj` namespace in `init.lua`. New generator files should be lowercased with hyphen-free names that match the registered key. Favor descriptive labels in TOML (e.g., `window:left-half`) and keep asset filenames lowercase with hyphens.

## Testing Guidelines
Automated tests are currently limited to configuration validation. Use `test-config.toml` as a safe sandbox before editing production configs. When adding new action types, load them in a throwaway key (`_dev`) and verify via the Hammerspoon console log. Capture console output if you hit warnings from `validateTomlStructure` and include them in review. Always confirm `auto_reload` behavior after touching filesystem watchers or URL handlers.

## Commit & Pull Request Guidelines
Follow the existing imperative tense, sentence-case single-line commit messages (see `git log` for examples like "Fix phantom conditional entries bug in Jammerflow submenus"). Each PR should describe motivation, approach, and testing notes; link any tracked issues or docs such as `setup.md`. Attach screenshots or short videos whenever UI changes are involved and call out new permissions required by macOS.

## Security & Configuration Tips
macOS permissions (Full Disk Access, Accessibility, Notifications) are mandatory—reference `setup.md` when changes may affect them. Avoid committing personal TOML secrets; prefer placeholders in `examples/`. If you introduce new URL handlers, guard them with scheme checks inside `init.lua` and document expected inputs in-line.
