-- Colorscheme for machines that are NOT Omarchy.
--
-- On Omarchy this file is ignored (see .chezmoiignore): there,
-- lua/plugins/theme.lua is a symlink into ~/.local/state/omarchy/current/theme/
-- and the colorscheme follows `omarchy theme set`.
--
-- Same spec as Omarchy's kanagawa theme (theme/neovim.lua), so macOS and the
-- 42 machines match the desktop. Change both together if the desktop theme moves.
return {
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "kanagawa" } },
}
