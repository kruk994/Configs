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
| `.chezmoidata/star-wars.yaml` | Star Wars theme palettes, the one place to edit them |
| `.chezmoitemplates/star-wars/` | renderers: Omarchy `colors.toml`, base24 scheme, `theme.env` |
| `dot_local/share/star-wars-themes/` | wallpapers + per-planet stubs calling those renderers |
| `dot_local/bin/executable_star-wars-theme` | `list` / `set` / `bg`, and the tinty desktop hook |
| `dot_config/tinted-theming/tinty/config.toml.tmpl` | tinty items, only for tools installed on the machine |
| `archive/mac-2026-08/` | the previous Mac snapshot, for reference |

## Star Wars themes

Five dark desktop themes -- **Tatooine, Hoth, Mustafar, Hyperspace,
Dagobah** -- each a palette plus 3--5 wallpapers, made to move between
machines. One command everywhere:

```sh
star-wars-theme list          # planets, * = current
star-wars-theme set hoth      # switch
star-wars-theme bg            # next wallpaper of the current planet
```

### Where things come from

```
.chezmoidata/star-wars.yaml ──► .chezmoitemplates/star-wars/*  (renderers)
                                     │
      ┌──────────────────────────────┼──────────────────────────────┐
  Omarchy                        other Linux                       macOS
  colors.toml + icons.theme      base24 scheme for tinty           nothing
  in ~/.local/share/             + theme.env for the desktop hook  (Ghostty keeps
  star-wars-themes/<planet>,                                        Kanagawa)
  symlinked into
  ~/.config/omarchy/themes
```

The palette uses Omarchy's `colors.toml` names; the 24 of them map one to
one onto base24 (`base00` background ... `base17` bright magenta, see
`.chezmoitemplates/star-wars/base24.yaml`). `accent`, the Hyprland border,
the GNOME accent and the Yaru icon variant sit beside it in the same file.

**Omarchy.** `star-wars-theme set` is `omarchy theme set star-wars-<planet>`
and Omarchy themes everything itself. tinty is not installed.

**Every other Linux (42 Ubuntu/GNOME, CachyOS/Hyprland, ...).** `chezmoi
apply` installs tinty (pinned, checksum-verified, into `~/.local/bin`) and
runs `tinty sync`. `star-wars-theme set` is `tinty apply
base24-star-wars-<planet>`, which builds the tinted-theming templates for the
custom scheme and then runs `star-wars-theme tinty-hook`:

| Target | How |
|---|---|
| shell / current terminal | tinted-shell OSC colours; new shells via `42.sh` |
| kitty, ghostty, foot, alacritty | file from tinted-terminal + one `include` line in their config (alacritty: printed hint if `alacritty.toml` already exists) |
| Neovim | tinted-vim file, sourced by `lua/plugins/colorscheme.lua`, re-sourced on focus |
| GTK4 / libadwaita, GTK3 | `~/.config/gtk-{4,3}.0/star-wars.css` + `@import` at the top of `gtk.css` (restart apps) |
| GNOME | dark style, wallpaper, accent (GNOME 47+, nearest of its 9 presets), Yaru icon variant if installed |
| Hyprland | border gradient in `~/.config/hypr/star-wars.{lua,conf}`, sourced from `hyprland.lua` / `hyprland.conf`, `hyprctl reload` |
| wallpaper on Hyprland | awww/swww, hyprpaper or swaybg -- whichever runs |
| Waybar | `@define-color` set in `~/.config/waybar/star-wars.css`, imported into `style.css`, reloaded |
| Quickshell & co. | `~/.local/state/star-wars-theme/colors.json` (palette, base00-17, wallpaper) |

Any other tinty scheme works the same way (`tinty apply base16-mocha`): the
desktop follows its palette, only the wallpaper stays.

On 42 Ubuntu this sits on top of the Kanagawa GNOME Terminal profile (see
*Colours*): until `star-wars-theme set` is run, nothing changes there.

Lines the hook adds to configs it does not own (`gtk.css`, `hyprland.*`,
`style.css`, terminal configs) are marked `star-wars-theme` and added once.

**Limits.** The GNOME Shell top bar keeps its own look (that needs a shell
theme extension). Waybar and Quickshell only change if their style/config uses
the generated colours -- the hook cannot know what a third-party config calls
them. Quickshell example (any config):

```qml
import Quickshell
import Quickshell.Io

FileView {
    path: Quickshell.env("HOME") + "/.local/state/star-wars-theme/colors.json"
    watchChanges: true
    onFileChanged: reload()
    adapter: JsonAdapter {
        id: sw
        property string accent
        property string background
        property string foreground
        property string wallpaper
    }
}
```

**42 quota.** Wallpapers take ~15 MB in `~/.local/share/star-wars-themes`;
tinty's template checkouts (`~/.local/share/tinted-theming`) add about as
much again. The terminal templates are cloned only when a supported terminal
is installed.

### Editing

- **Colours:** edit `.chezmoidata/star-wars.yaml`, `chezmoi apply`, then
  `star-wars-theme set <planet>` again.
- **Wallpapers:** drop a file into
  `dot_local/share/star-wars-themes/<planet>/backgrounds/` (they show in name
  order; the first is the preview). Keep them 2560x1440 or larger.
- **New planet:** a new key in `star-wars.yaml`, and a new directory copied
  from an existing planet -- the stubs work out the planet from their own
  path. Then copy the scheme stub in
  `dot_local/share/tinted-theming/tinty/custom-schemes/base24/` and the
  Omarchy symlink in `dot_config/omarchy/themes/`, renamed.

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
runs `starship init bash` itself. The check is starship's precmd function, not
`$STARSHIP_SHELL`: that variable is exported, so shells started inside herdr,
tmux or nvim inherited it and came up with the bare zsh prompt.

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
2. **tree-sitter CLI v0.25.10**, pinned: nvim-treesitter compiles its parsers
   with it, and every release since 0.26 needs glibc 2.39 (Ubuntu 22.04 has
   2.35). A copy Mason already fetched that cannot run is deleted, because
   Mason's `bin/` comes first on nvim's PATH. `:checkhealth` warns that it
   wants 0.26.1 -- harmless, that is only for `generate`.
3. **ripgrep** and **fd** (static musl builds, pinned) for LazyVim's pickers.
4. **herdr** via its official installer.
5. **Claude Code** via its native installer (~220 MB per version; home quota).
6. **starship** via its official installer.
7. **norminette** in a venv, or `pip --user` when the lab lacks `python3-venv`.
8. **JetBrainsMono Nerd Font**, only the Regular/Bold/Italic/BoldItalic faces
   (~10 MB rather than ~120 MB for the whole archive, for the home quota),
   then `fc-cache`. Skipped if `fc-list` already knows the font.
9. **GNOME Terminal** default profile: font set to *JetBrainsMono Nerd Font 12*
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

Ghostty (the terminal used on the Air since 2026-10-07) gets its font, the
Kanagawa palette and the Option-as-Alt settings from `dot_config/ghostty/config.tmpl`,
so nothing needs picking by hand there.

**One manual step chezmoi cannot do — herdr's prefix.** macOS takes ⌃Space for
"Select the previous input source", so herdr never sees `ctrl+space`. Turn it
off: System Settings → Keyboard → Keyboard Shortcuts… → Input Sources →
untick *Select the previous input source*. Takes effect immediately.

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
