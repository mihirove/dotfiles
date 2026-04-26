# dotfiles

[![macOS](https://img.shields.io/badge/macOS-aarch64-blue.svg)](https://www.apple.com/macos/)
[![Nix](https://img.shields.io/badge/Nix-flakes-5277C3.svg)](https://nixos.wiki/wiki/Flakes)
[![nix-darwin](https://img.shields.io/badge/nix--darwin-managed-success.svg)](https://github.com/LnL7/nix-darwin)
[![home-manager](https://img.shields.io/badge/home--manager-managed-success.svg)](https://github.com/nix-community/home-manager)

Declarative macOS dotfiles managed with [Nix flakes](https://nixos.wiki/wiki/Flakes), [nix-darwin](https://github.com/LnL7/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager). One `nix run .#switch` rebuilds the system: shell, editor, terminals, fonts, GUI apps, language runtimes, GPG agent, Tailscale, all at once and pinned by `flake.lock`.

## Hosts

`flake.nix` declares one entry per machine. Both run [official Nix](https://nixos.org/download) so that nix-darwin can manage the daemon, GC, and `/etc/nix/nix.conf` consistently. The `determinate = true` opt-in is wired through `lib/mkHost.nix` for future hosts that prefer [Determinate Nix](https://install.determinate.systems/).

| Host | Nix installer | `nix.enable` |
|---|---|---|
| `mac` | official | `true` |
| `mac-mini` | official | `true` |

`nix run .#switch` reads the current `LocalHostName` (`scutil --get LocalHostName`) and applies the matching `darwinConfigurations.<host>`. Override with the `DARWIN_HOST` env var when bootstrapping a fresh machine whose hostname has not been set yet.

## Quick start (fresh Mac)

```bash
# 1. Install official Nix (multi-user). Same installer for every host.
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Enable flakes for the bootstrap shell only — the system-level
#    /etc/nix/nix.conf is set declaratively by darwin/nix.nix on the
#    very next switch.
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# 3. Clone this repo
git clone git@github.com:mihirove/dotfiles.git ~/Documents/personal/dotfiles
cd ~/Documents/personal/dotfiles

# 4. Activate. The host's flake entry is picked from the current
#    LocalHostName; on a fresh machine override it once until the
#    nix-darwin activation sets the hostname for you.
DARWIN_HOST=mac-mini nix run .#switch    # first-time bootstrap
nix run .#switch                         # subsequent rebuilds
```

To add a new host, edit the `hosts` attrset at the top of `flake.nix`:

```nix
hosts = {
  mac      = { determinate = false; };
  mac-mini = { determinate = false; };
  new-host = { determinate = false; };
};
```

## Daily commands

```bash
nix run .#build      # build into ./result without activating
nix run .#switch     # build + activate (sudo prompt)
nix run .#update     # nix flake update
nix flake check      # type-check all options
```

These wrap the underlying `darwin-rebuild` and `nix flake` invocations so the host name does not have to be retyped.

## Repository layout

```text
dotfiles/
├── flake.nix              # inputs (nixpkgs, nix-darwin, home-manager) + outputs (darwinConfigurations + apps)
├── flake.lock
├── lib/
│   └── mkHost.nix         # darwinSystem factory; passes specialArgs (incl. dotfilesPath, determinate)
│
├── darwin/                # nix-darwin (system-level, root-managed)
│   ├── default.nix        # imports the rest, sets hostName + nixpkgs.hostPlatform
│   ├── nix.nix            # nix.* settings (no-op when determinate = true)
│   ├── system.nix         # system.stateVersion, primaryUser, defaults
│   ├── users.nix          # users.users.<name>, login shell
│   ├── homebrew.nix       # cask + brew formula declarations
│   ├── fonts.nix          # fonts.packages (Nerd Fonts)
│   └── tailscale.nix      # services.tailscale.enable
│
├── home/                  # home-manager (user-level)
│   ├── default.nix        # imports + home.{username,homeDirectory,stateVersion}
│   ├── packages.nix       # CLI tools as home.packages
│   ├── runtimes.nix       # node / python / go / rust / java / etc.
│   └── programs/
│       ├── zsh.nix        # programs.zsh + initContent
│       ├── git.nix        # programs.git (settings, aliases, includes, ignores)
│       ├── tmux.nix       # tmux + xdg.configFile."tmux/tmux.conf"
│       ├── neovim.nix     # programs.neovim + mkOutOfStoreSymlink to ../../nvim
│       ├── kitty.nix      # mkOutOfStoreSymlink to ../../kitty
│       ├── karabiner.nix  # mkOutOfStoreSymlink to ../../karabiner
│       ├── ghostty.nix    # mkOutOfStoreSymlink to ../../cmux/ghostty
│       ├── claude.nix     # ~/.claude/* mkOutOfStoreSymlink
│       ├── iterm2.nix     # defaults import + killall cfprefsd
│       ├── fzf.nix        # programs.fzf + everforest palette
│       ├── gh.nix         # programs.gh
│       └── gpg.nix        # ~/.gnupg/gpg-agent.conf with pinentry_mac
│
├── nvim/                  # init.lua + lua/ (managed by lazy.nvim, repo-writable)
├── kitty/                 # kitty.conf, kitty.d/, kitty-themes/, ...
├── karabiner/karabiner.json
├── claude/                # CLAUDE.md, settings.json, skills/, statusline-command.sh
├── cmux/                  # ghostty/config, settings.json
├── tmux/tmux.conf
└── iterm/com.googlecode.iterm2.plist
```

The `mkOutOfStoreSymlink` modules point at the repo path (`/Users/<user>/Documents/personal/dotfiles/...`) so tools that write back to their config (lazy.nvim's `lazy-lock.json`, Karabiner-Elements GUI) keep working — the file edited is the file in the repo.

## What the flake manages today

| Layer | Source |
|---|---|
| **Nix CLI tools** | `home/packages.nix` — fd, fzf, gh, ghq, jq, lua, prettierd, ripgrep, tree, tree-sitter, asciinema, asciinema-agg, pstree, gnupg, google-cloud-sdk, kitty, maccy |
| **Language runtimes** | `home/runtimes.nix` — Node 24, Python 3.13, Go, Rust (cargo+rustc+rustfmt), Bun, OpenJDK 21 LTS, awscli2, ffmpeg, firebase-tools, pnpm, uv, yarn-berry |
| **System fonts** | `darwin/fonts.nix` — `nerd-fonts.monaspace` |
| **Tailscale** | `darwin/tailscale.nix` — `services.tailscale.enable = true` (CLI + tailscaled launchd daemon) |
| **Brew casks** | `darwin/homebrew.nix` — `fork`, `orbstack` (apps that need privileged installers) |
| **Brew formulae** | `darwin/homebrew.nix` — `phantom` only ([Git worktree manager](https://github.com/phantompane/phantom); not in nixpkgs) |
| **iTerm2 plist** | `home/programs/iterm2.nix` — `defaults import` + `killall cfprefsd` activation |

`homebrew.onActivation.cleanup = "uninstall"`: anything brew has installed that is not in `brews` / `casks` is removed on the next switch.

## Common tasks

### Update an upstream package

```bash
nix run .#update              # all inputs
nix flake update home-manager # one input
nix run .#switch              # apply
```

### Add a CLI

Edit `home/packages.nix`, append the attribute name, then `nix run .#switch`.

### Add a brew cask

Edit the `casks = [ ... ]` list in `darwin/homebrew.nix`. Removing a line uninstalls the cask (because of `cleanup = "uninstall"`).

### Roll back

`darwin-rebuild` keeps the last few generations:

```bash
sudo darwin-rebuild --list-generations
sudo darwin-rebuild switch --flake .#mac~1   # previous generation on the `mac` host
```

## Secrets

Tokens and per-host work credentials live in `~/.secrets.zsh` (git-ignored, sourced from the end of `programs.zsh.initContent`). Example:

```sh
# ~/.secrets.zsh
if [ -f ~/.config/tavily/apps.json ]; then
    export TAVILY_API_KEY=$(jq -r '."api_key"' ~/.config/tavily/apps.json 2>/dev/null)
fi

export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/legacy_credentials/<work-email>/adc.json"
```

## Caveats

- **macOS App Management permission**: the first activation that touches `~/Applications/Home Manager Apps/` (kitty / Maccy via nix) requires you to grant the active terminal "App Management" in System Settings → Privacy & Security.
- **Tailscale state**: `services.tailscale.enable` keeps the auth state at `/Library/Tailscale/tailscaled.state`. Migrating from the brew formula adopts that path automatically — no re-login required.
- **Determinate Nix opt-in**: a host can flip to [Determinate Nix](https://install.determinate.systems/) by setting `determinate = true;` in the `hosts` attrset. That makes `darwin/nix.nix` set `nix.enable = false` and skips the `nix.gc` / `nix.settings` / `nix.optimise` options because Determinate manages its own daemon. None of today's hosts use this.
- **`DARWIN_HOST` override**: on a brand-new machine, `LocalHostName` reflects the macOS default (e.g. `Mihiros-Mac-mini`), not the flake-side host name. Pass `DARWIN_HOST=<flake-host>` for the first activation; the switch sets `LocalHostName` and subsequent runs auto-detect.

## License

MIT.
