# configs

Cross-device dotfiles for **Omarchy** (MacBook Pro), **macOS** (MacBook Air M4)
and **42 Warsaw Ubuntu** lab machines, managed with
[chezmoi](https://chezmoi.io).

## Part of ARK

This repo is **layer 2 of ARK**, the two-layer system that reproduces the setup
on a new machine:

| Layer | Where | Scope |
|---|---|---|
| 1 | `~/git/omarchy_ARK/reapply.sh` | Omarchy + MacBook hardware: drivers, DKMS, keyd, Hyprland, packages, system files. Needs sudo, not portable. |
| 2 | this repo | Portable dotfiles rendered into `$HOME` on all three machines. No sudo. |

Which layer does a change belong in? Ask whether it would make sense on the M4
Air or a 42 lab machine — yes → here, no → `reapply.sh`. Anything Omarchy- or
hardware-specific stays out of this repo.

The design principle is *Omarchy defaults first*: every machine runs the stock
Omarchy/LazyVim base, and this repo adds a thin 42-school overlay on top.

## The one rule

> **Never put an `exact_` prefix on any directory under `dot_config/nvim`.**

Omarchy owns files inside `~/.config/nvim` — above all
`lua/plugins/theme.lua`, which is a **symlink** into
`~/.local/state/omarchy/current/theme/` and is how `omarchy theme set` swaps the
Neovim colorscheme. chezmoi only writes files that are in its source state and
leaves unmanaged files alone; `exact_` is the single thing that would make it
delete them. `.chezmoiignore` names those paths explicitly as a second line of
defence.

Check before every commit:

```sh
find . -name 'exact_*' -not -path './.git/*'   # must print nothing
```

## Setup on a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin   # if chezmoi is missing
git clone https://github.com/<you>/configs ~/git/configs
chezmoi init --source=~/git/configs                       # prompts for 42 login + email
chezmoi diff                                              # review
chezmoi apply
```

The `--source` flag is needed only on that first `init`: it writes `sourceDir`
into `~/.config/chezmoi/chezmoi.toml`, and every later `chezmoi` command finds
the repo on its own. Without a TTY (a script, CI), the prompts are skipped and
the defaults used; values can also be passed up front:

```sh
chezmoi init --source=~/git/configs \
  --promptString "42 login=jnandzik" \
  --promptString "42 email=jnandzik@student.42warsaw.pl"
```

`chezmoi init` detects the machine class automatically (`omarchy` / `macos` /
`42` / `generic`) and asks once for the 42 login and email, which are stored in
`~/.config/chezmoi/chezmoi.toml`. They are kept separate from the system
`$USER`, which differs per machine.

## How chezmoi works (in one minute)

chezmoi does not symlink. It **renders files from this repo into `$HOME`**.

```
~/git/configs/                       ~/
  dot_config/nvim/...      --->        .config/nvim/...
  dot_gitconfig.tmpl       --->        .gitconfig     (templated per machine)
```

1. **Naming is the mapping.** `dot_` becomes `.`, so `dot_gitconfig` is
   `~/.gitconfig`. A `.tmpl` suffix means "run this through the template engine
   first"; the suffix is dropped in the output.
2. **`chezmoi init`** reads `.chezmoi.toml.tmpl`, detects the machine, asks for
   your identities once, and writes the answers to
   `~/.config/chezmoi/chezmoi.toml`. That file is per-machine and is NOT in git.
3. **Templates** branch on those answers — `{{ if eq .machine "macos" }}` picks
   `pbcopy`, `{{ .user42 }}` stamps your 42 login. One source file, three
   different rendered outputs.
4. **`chezmoi diff`** shows exactly what would change in `$HOME`. Always run it
   before applying.
5. **`chezmoi apply`** writes the rendered files, then runs any `run_onchange_`
   scripts whose contents changed.
6. **Editing later:** change the file *here* and `chezmoi apply`. If you edited
   the copy in `$HOME` by hand instead, pull it back with
   `chezmoi re-add ~/.gitconfig`. `chezmoi status` lists anything out of sync.

The key safety property: chezmoi only ever writes files that exist in this
repo. Anything else in `$HOME` — all of Omarchy's own config — is invisible to
it, unless a directory is marked `exact_`, which is why that prefix is banned
here.

## Layout

| Path | Purpose |
|---|---|
| `.chezmoi.toml.tmpl` | machine detection, prompts for the 42 identity |
| `.chezmoiignore` | repo-only paths + the Omarchy guard |
| `.chezmoidata/kanagawa.toml` | terminal palette shared by Ghostty (macOS) and GNOME Terminal (42) |
| `dot_config/nvim/` | 42 overlay on the stock LazyVim starter |
| `dot_config/shell/42.sh.tmpl` | POSIX fragment sourced by bash and zsh |
| `dot_config/tmux/tmux.conf.tmpl` | Omarchy's tmux base + herdr parity |
| `dot_config/starship.toml` | prompt: full path + git detail, Nerd Font icons, ANSI colours so it follows the theme (also in nvim `:terminal`); legend: `prompt-help` |
| `run_onchange_*` | idempotent, sudo-free bootstrap |
| `archive/mac-2026-08/` | the previous Mac snapshot, for reference |

## Prompt (starship)

`dot_config/starship.toml` gives a two-line prompt: full path, detailed git
state (branch, ahead/behind, staged/modified/untracked counts, lines added and
removed, rebase/merge progress), language versions, command duration, exit
code and time. Run **`prompt-help`** for a legend of every icon.

It uses only ANSI colour names, so it follows whatever palette the terminal
has: `omarchy theme set` changes it, and inside Neovim's `:terminal` the
colorscheme's `terminal_color_*` apply. No per-theme template is needed.

Starship is started from `42.sh` on every machine (zsh on macOS and at 42,
bash on Omarchy), unless the shell rc already did it -- Omarchy's bash rc
runs `starship init bash` itself, and the `STARSHIP_SHELL` check skips the
second init.

| Machine | starship | Nerd Font (icons) |
|---|---|---|
| Omarchy | shipped | shipped, terminals already use it |
| 42 Ubuntu | **automatic**: `chezmoi apply` installs it into `~/.local/bin` | **automatic**: installed into `~/.local/share/fonts`, and GNOME Terminal's default profile switched to it |
| macOS | `brew install starship` | `brew install --cask font-jetbrains-mono-nerd-font`, then pick the font in the terminal |

Without a Nerd Font selected in the terminal, the icons render as empty
boxes -- installing the font alone changes nothing.

### 42 Ubuntu: what `chezmoi apply` does

`run_onchange_before_10-install-tools.sh.tmpl`, all without sudo, everything
into `~/.local`, each step skipped when the tool is already there:

1. **Neovim** (release tarball; Ubuntu's package is too old for LazyVim). The
   binary is run once before it is copied, so a release that needs a newer
   glibc than 22.04's 2.35 leaves the old nvim in place.
2. **ripgrep** and **fd** (static musl builds, pinned) for LazyVim's pickers.
3. **herdr** via its official installer.
4. **starship** via its official installer.
5. **norminette** in a venv, or `pip --user` when the lab lacks `python3-venv`.
6. **JetBrainsMono Nerd Font**, only the Regular/Bold/Italic/BoldItalic faces
   (~10 MB rather than ~120 MB for the whole archive, for the home quota),
   then `fc-cache`. Skipped if `fc-list` already knows the font.
7. **GNOME Terminal** default profile: font set to *JetBrainsMono Nerd Font 12*
   (only while the profile still uses the system font, so a font chosen by hand
   is never overwritten), **Kanagawa colours** (always), dark window chrome.

`run_onchange_after_20-hook-shell-rc.sh.tmpl` creates `~/.zshrc` if zsh is the
login shell and the file is missing, then hooks `42.sh` into it. `42.sh` also
turns on saved history and Tab completion in zsh -- Ubuntu's `/etc/zsh/zshrc`
does neither -- unless oh-my-zsh or a campus `.zshrc` already did.

Open a new terminal afterwards. If the icons are still boxes, set the font by
hand: GNOME Terminal → ☰ → Preferences → the profile → *Custom font*.

The script runs again only when its contents change. To repeat the install on
the same machine (e.g. after wiping the fonts):

```sh
chezmoi state delete-bucket --bucket=scriptState && chezmoi apply
```

### macOS (Air)

```sh
brew install starship
brew install --cask font-jetbrains-mono-nerd-font
```

Then Terminal → Settings → Profiles → Text → Font, or iTerm2 → Settings →
Profiles → Text → Font → *JetBrainsMono Nerd Font*. (The archived MartianMono
Nerd Font in `archive/mac-2026-08/` works too.)

## Colours (Kanagawa everywhere)

`.chezmoidata/kanagawa.toml` holds the palette of the Omarchy desktop theme and
is the single source for every terminal this repo colours:

| Machine | Terminal | Where the palette goes |
|---|---|---|
| Omarchy | Ghostty / Alacritty | not from here -- `omarchy theme set` owns it |
| macOS | Ghostty | `dot_config/ghostty/config.tmpl` |
| 42 Ubuntu | GNOME Terminal | default profile, via `gsettings` in the install script |

Everything else follows the terminal: starship, tmux and herdr use ANSI colour
names only, and Neovim's `kanagawa` colorscheme has the same `#1f1f28`
background. Change the palette in the TOML file and `chezmoi apply` -- the
install script re-runs because its rendered contents changed.

## Neovim

The base is the untouched Omarchy LazyVim starter. This repo adds:

- **42 Norm indentation for C** — real tabs at 4 columns, scoped to `c`/`cpp`
  only. See the long comment in `lua/config/autocmds.lua`: LazyVim's treesitter
  `indentexpr` returns `-1` on every line of a C buffer and outranks `cindent`,
  which is what misaligns braces. Clearing it (deferred, so it beats
  `LazyVim.set_default`) hands indenting to `cindent`, whose *default*
  `cinoptions` are already Norm-correct.
- **`lang.clangd`** — clangd for real errors, completion and go-to-definition.
  Configured with `mason = false` whenever a system `clangd` exists, so Mason
  does not download a duplicate ~100 MB copy (it matters against the 42 home
  quota). clang-format is never allowed to run on C
  (`vim.b.autoformat = false`).
- **`42-header.nvim`** — `<F1>`, auto-refreshed on save.
- **`norm42`** — norminette as diagnostics, async with a hard 3 s timeout.
  norminette 3.3.59 hangs forever on a function call missing a semicolon; the
  timeout is what stops that from freezing the editor.

Commands: `:Norm` `:NormOn` `:NormOff` `:NormLimit <n>` `:NormDebug`.

### After updating plugins, run `:TSUpdate`

`:Lazy sync` updates the nvim-treesitter **plugin**, which refreshes the query
files in `~/.local/share/nvim/site/queries/` — but it does **not** rebuild the
compiled parsers in `~/.local/share/nvim/site/parser/`. When the new queries
reference a grammar node the old parser lacks, you get

```
query.lua:374: Query error at 113:4. Invalid node type "tab"
```

which breaks noice's cmdline highlighting: the command line stops appearing as
a popup and falls back to the bottom of the screen with garbled rendering.

Fix, and the habit to keep: **run `:TSUpdate` after any treesitter plugin
update.** To check for the problem:

```vim
:lua print(pcall(vim.treesitter.query.get, "vim", "highlights"))
```

(`html_tags`, `ecma` and `jsx` always report "no parser" — they are query-only
pseudo-languages, not a fault.)
