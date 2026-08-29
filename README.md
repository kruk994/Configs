# configs

Cross-device dotfiles for **Omarchy** (MacBook Pro), **macOS** (MacBook Air M4)
and **42 Warsaw Ubuntu** lab machines, managed with
[chezmoi](https://chezmoi.io).

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
| `dot_config/nvim/` | 42 overlay on the stock LazyVim starter |
| `dot_config/shell/42.sh.tmpl` | POSIX fragment sourced by bash and zsh |
| `dot_config/tmux/tmux.conf.tmpl` | Omarchy's tmux base + herdr parity |
| `run_onchange_*` | idempotent, sudo-free bootstrap |
| `archive/mac-2026-08/` | the previous Mac snapshot, for reference |

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
