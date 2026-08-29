-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- ── Twarde wymuszenie tabow w C ─────────────────────────────────────────────
-- Ustawienia globalne moze nadpisac ftplugin, .editorconfig albo LSP.
-- To jest ostatnie slowo: leci przy kazdym otwarciu bufora C.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 0
  end,
})

-- ── Zadnego autoformatowania w C ────────────────────────────────────────────
-- Dzis nieszkodliwe (nie masz extras lang.c, wiec nie ma clang-format).
-- W dniu, w ktorym go dodasz, conform.nvim zaczalby przeformatowywac pliki C
-- przy kazdym zapisie i rozjezdzalby norme. To jest bezpiecznik na przyszlosc.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.b.autoformat = false
  end,
})
