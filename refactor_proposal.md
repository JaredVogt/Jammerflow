# Hammerflow Repository Separation Plan

## Goal
Create `JaredVogt/HSFlow` as an independent public repo (no fork relationship with Sam's original).

## Current State
```
~/.hammerspoon/Spoons/Hammerflow.spoon/   # Sam's repo with symlinks → messy
    ├── .git (origin: saml-dev/Hammerflow.spoon)
    ├── init.lua → symlink to dotfiles
    ├── config.toml → symlink to dotfiles
    ├── DynamicMenu → symlink to dotfiles
    └── ...other symlinks

dotfiles.v2/hammerspoon/Hammerflow/       # YOUR actual code
    ├── init.lua (59KB - heavily enhanced)
    ├── config.toml (personal shortcuts)
    ├── DynamicMenu/ (your innovation)
    ├── RecursiveBinder/ (enhanced)
    └── ... all your work
```

## Target State
```
~/projects/HSFlow/           # NEW standalone repo
    ├── .git (origin: JaredVogt/HSFlow)
    ├── init.lua
    ├── DynamicMenu/
    ├── RecursiveBinder/
    ├── example_config.toml               # Generic example (no personal data)
    └── ...

~/.hammerspoon/Spoons/Hammerflow.spoon    # Symlink to new repo
    → ~/projects/HSFlow

dotfiles.v2/hammerspoon/
    ├── config.toml                       # Your personal config only
    └── setup-hammerflow.sh               # Installation script
```

## Execution Plan

### Step 1: Create GitHub Repo
```bash
gh repo create JaredVogt/HSFlow --public --description "Enhanced Hammerflow with DynamicMenu, background images, and more"
```

### Step 2: Initialize New Repo Location
```bash
mkdir -p ~/projects/HSFlow
cd ~/projects/HSFlow
git init
git remote add origin git@github.com:JaredVogt/HSFlow.git
```

### Step 3: Copy Enhanced Code (excluding personal config)
```bash
# Copy all code from dotfiles
cp -r ~/projects/dotfiles.v2/hammerspoon/Hammerflow/* ~/projects/HSFlow/

# Remove personal config, create generic example
mv config.toml personal_config.toml.bak
# Will create example_config.toml with generic shortcuts
```

### Step 4: Create example_config.toml
Strip personal data:
- Remove Wolffaudio Linear URLs
- Remove personal KM macro names
- Keep generic examples for all features
- Document all action types with examples

### Step 5: Clean Up Files to Exclude
Remove from new repo:
- `refactor_proposal.md` (internal planning)
- `todo.md` (personal)
- `needicons.md` (personal)
- `configplan.md` (internal)
- `*.bak` files
- Personal config variations

### Step 6: Update Attribution
Add to README.md:
```markdown
## Credits
Originally forked from [saml-dev/Hammerflow.spoon](https://github.com/saml-dev/Hammerflow.spoon).
Significantly enhanced with DynamicMenu system, background images, and more.
```

### Step 7: Initial Commit & Push
```bash
git add .
git commit -m "Initial release of HSFlow

Major enhancements over original Hammerflow:
- DynamicMenu system with modular generators
- Background image support (GIF, PNG, opacity)
- Browser tab generators (Chrome, Canary, Claude Web)
- Keyboard Maestro integration with variables
- Enhanced window management with pixel positioning
- HTML formatting in labels
- Per-menu layout options
- TOML validation

Message by Claude"
git push -u origin main
```

### Step 8: Remove Sam's Repo & Create Symlink
```bash
# Backup just in case
mv ~/.hammerspoon/Spoons/Hammerflow.spoon ~/.hammerspoon/Spoons/Hammerflow.spoon.saml-backup

# Create symlink to your new repo
ln -s ~/projects/HSFlow ~/.hammerspoon/Spoons/Hammerflow.spoon
```

### Step 9: Update Dotfiles
In `dotfiles.v2/hammerspoon/`:
1. Remove the `Hammerflow/` directory (it's now external)
2. Keep only `config.toml` (your personal config)
3. Create symlink: `~/.hammerspoon/Spoons/Hammerflow.spoon/config.toml → dotfiles.v2/hammerspoon/config.toml`
4. Add `setup-hammerflow.sh` installation script

### Step 10: Verify Everything Works
```bash
# Reload Hammerspoon
osascript -e 'tell application "Hammerspoon" to reload preferences'
```

## Files to Create

### example_config.toml
Generic example with:
- Sample app shortcuts (generic apps)
- Dynamic menu examples (all generators)
- Window management presets
- Search menu example
- Submenu examples

### setup-hammerflow.sh
```bash
#!/usr/bin/env bash
# Clone HSFlow
git clone git@github.com:JaredVogt/HSFlow.git ~/projects/HSFlow

# Create Spoon symlink
ln -sf ~/projects/HSFlow ~/.hammerspoon/Spoons/Hammerflow.spoon

# Symlink personal config (edit path as needed)
ln -sf ~/projects/dotfiles.v2/hammerspoon/config.toml ~/.hammerspoon/Spoons/Hammerflow.spoon/config.toml

echo "HSFlow installed! Reload Hammerspoon."
```

## Dotfiles Changes Summary

**Remove from dotfiles.v2:**
- `hammerspoon/Hammerflow/` entire directory

**Keep in dotfiles.v2:**
- `hammerspoon/config.toml` (personal config)
- `hammerspoon/setup-hammerflow.sh` (installation script)
