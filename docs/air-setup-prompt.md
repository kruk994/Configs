# Prompt to run on the MacBook Air (macOS)

After cloning this repo to `~/git/configs`, `cd` into it and give Claude Code
this prompt. It covers the two things that could not be tested on the Omarchy
machine: the zsh path, and macOS-specific differences.

---

I've just cloned my cross-device dotfiles repo to ~/git/configs on my MacBook
Air (macOS, zsh as login shell). It is a chezmoi source directory that was
built and verified on my Omarchy (Arch/Linux) machine, but the macOS and zsh
paths through it have NEVER been executed. Read the README.md first, then set
it up here carefully.

Before applying anything, verify these specific risks and report what you find:

1. ZSH: `dot_config/shell/42.sh.tmpl` is POSIX and was only ever sourced under
   bash. Confirm it is zsh-clean — check the `case "$PATH" in` PATH guard, the
   `mkcd` and `subject` functions, and that no alias collides with something
   Oh My Zsh or macOS already defines. Note that `alias cc='cc -Wall -Wextra
   -Werror'` shadows the compiler; confirm that is safe with how zsh expands
   aliases in scripts and Makefiles.

2. The `run_onchange_after_20-hook-shell-rc.sh.tmpl` script appends a source
   line to ~/.zshrc, but only `if [ -f "$rc" ]`. If ~/.zshrc does not exist yet
   on this machine, the hook silently does nothing and the 42 aliases will
   never load. Check whether ~/.zshrc exists and fix the script if needed.

3. Machine detection in `.chezmoi.toml.tmpl` should classify this box as
   "macos". Verify with `chezmoi data | grep machine` after init.

4. macOS specifics to confirm before apply:
   - `dot_config/tmux/tmux.conf.tmpl` selects `pbcopy` when machine == macos.
   - `dot_config/nvim/lua/config/options.lua.tmpl` must NOT emit the
     `require("config.remote_clipboard")` line here — that file is Omarchy-only
     and requiring it would error on startup.
   - `lua/plugins/colorscheme.lua` IS applied here (it is ignored only on
     Omarchy, where the theme is an Omarchy symlink). Confirm nvim gets a
     colorscheme.
   - `clangd`: `lua/plugins/lang-c.lua` sets `mason = false` only when a system
     clangd exists. Check `which clangd` (Xcode command line tools) and confirm
     the right branch is taken.
   - norminette installs into a venv at ~/.local/share/norminette-venv. Verify
     python3 is available and that ~/.local/bin is on PATH in zsh.

5. Git identity: ~/.gitconfig is managed and carries my personal identity, with
   `includeIf` rules switching to my 42 identity for `~/git/42*/` and for any
   repo with a vogsphere remote. Confirm both rules resolve correctly here, and
   that `useConfigOnly = true` does not break any existing repo.

Setup steps:

    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin   # if chezmoi missing
    chezmoi init --source=~/git/configs                        # prompts for identities
    chezmoi diff                                               # REVIEW BEFORE APPLYING
    chezmoi apply

Do not run `chezmoi apply` until you have shown me the diff and explained
anything that would overwrite an existing file. After applying, verify:
- open a .c file and confirm `:set indentexpr?` is empty, `noexpandtab`,
  ts=4, sw=4, and that typing an if/else/switch block produces real tabs with
  aligned Allman braces
- `:Norm` produces norminette diagnostics
- `<F1>` inserts a 42 header stamped with my 42 login, not my macOS username
- `:LspInfo` shows clangd attached
- a new zsh login shell has $USER42 set and `mkcd` defined
