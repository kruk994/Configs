-- Colorscheme for machines that are NOT Omarchy.
--
-- On Omarchy this file is ignored (see .chezmoiignore): there,
-- lua/plugins/theme.lua is a symlink into ~/.local/state/omarchy/current/theme/
-- and the colorscheme follows `omarchy theme set`.
--
-- Once a tinty theme has been applied (star-wars-theme set <planet>), Neovim
-- follows it: tinty writes the tinted-vim colours to one fixed file, which is
-- sourced at startup and again on focus when it has changed. Until then -- and
-- on macOS, which has no tinty -- the same spec as Omarchy's kanagawa theme
-- (theme/neovim.lua), so the machines match the desktop. Change both together
-- if the desktop theme moves.
local data = os.getenv("XDG_DATA_HOME") or (vim.env.HOME .. "/.local/share")
local tinty = data .. "/tinted-theming/tinty/tinted-vim-colors-file.vim"

local function mtime()
  local st = vim.uv.fs_stat(tinty)
  return st and st.mtime.sec or nil
end

if not mtime() then
  return {
    { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
    { "LazyVim/LazyVim", opts = { colorscheme = "kanagawa" } },
  }
end

local loaded
local function load()
  loaded = mtime()
  vim.cmd.source(tinty)
end

vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    if mtime() and mtime() ~= loaded then
      load()
    end
  end,
})

return {
  { "LazyVim/LazyVim", opts = { colorscheme = load } },
}
