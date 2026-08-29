-- Colorscheme for machines that are NOT Omarchy.
--
-- On Omarchy this file is ignored (see .chezmoiignore): there,
-- lua/plugins/theme.lua is a symlink into ~/.local/state/omarchy/current/theme/
-- and the colorscheme follows `omarchy theme set`.
return {
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}
