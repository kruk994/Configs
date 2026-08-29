-- Options are automatically loaded before lazy.nvim startup
-- Defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- ── PATH ────────────────────────────────────────────────────────────────────
-- Neovim odpala zewnetrzne narzedzia (norminette, rg, fd) przez /bin/sh,
-- ktory NIE czyta ~/.zshrc. Jesli nvim wystartuje z launchera albo z innej
-- powloki, ~/.local/bin moze go nie byc w PATH i pluginy cicho nic nie robia.
-- Dopisujemy go tutaj — dziala identycznie na macOS i na Ubuntu.
local local_bin = vim.fn.expand("~/.local/bin")
if vim.fn.isdirectory(local_bin) == 1 and not string.find(vim.env.PATH or "", local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. (vim.env.PATH or "")
end

-- ── Wciecia pod norme 42 ────────────────────────────────────────────────────
-- Norma wymaga PRAWDZIWYCH tabow. LazyVim domyslnie ustawia expandtab = true,
-- wiec to musi byc nadpisane globalnie (a w autocmds.lua jeszcze raz per-buffer).
vim.opt.expandtab = false -- TAB wstawia znak tabulacji, NIE spacje
vim.opt.tabstop = 4 -- tabulacja wyswietla sie jako 4 kolumny
vim.opt.shiftwidth = 4 -- >> i << przesuwaja o 4
vim.opt.softtabstop = 0 -- 0 = nigdy nie mieszaj tabow ze spacjami

-- ── Pomoc przy normie ───────────────────────────────────────────────────────
vim.opt.colorcolumn = "81" -- limit dlugosci linii widoczny na oczy
vim.opt.list = true
vim.opt.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" } -- trailing whitespace to blad normy
