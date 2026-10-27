-- Autocmds are automatically loaded on the VeryLazy event.
-- Defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- ══════════════════════════════════════════════════════════════════════════
--  C / C++ : 42 Norm indentation
--
--  WHY THIS EXISTS -- measured, not guessed:
--  LazyVim sets `indentexpr = v:lua.LazyVim.treesitter.indentexpr()` for C
--  (lazyvim/plugins/treesitter.lua). That function returns -1 on every line of
--  a C buffer, and because `indentexpr` outranks `cindent`, the C ftplugin's
--  `cindent` never runs -- Vim falls back to bare `autoindent`, which just
--  copies the previous line's indent. Result: pressing Enter after `if (...)`
--  and opening a brace leaves the braces misaligned, breaking the Norm.
--
--  Setting expandtab/tabstop/shiftwidth alone does NOT fix this (verified);
--  the indentexpr has to be cleared so cindent takes over. With cindent in
--  charge, Vim's DEFAULT cinoptions already produce Norm-correct output:
--  Allman braces, `else` aligned with `if`, `case` one level inside `switch`.
--  No cinoptions tuning is needed.
--
--  WHY vim.schedule():
--  LazyVim assigns the indentexpr via `LazyVim.set_default("indentexpr", ...)`,
--  which writes only when the option is still at its default -- and "" IS the
--  default. So clearing it synchronously (here or in after/ftplugin) loses the
--  race. Deferring guarantees we run after every synchronous FileType handler.
--
--  Scope is deliberately C/C++ only. The old Mac config set noexpandtab and
--  ts=4 globally, which imposed 42 tabs on Lua, JSON and everything else;
--  LazyVim's 2-space default stays in force outside C.
-- ══════════════════════════════════════════════════════════════════════════
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("norm42_indent", { clear = true }),
  pattern = { "c", "cpp" },
  callback = function(ev)
    local buf = ev.buf

    -- The Norm requires REAL tabs, displayed as 4 columns.
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 0 -- 0 = never mix tabs with spaces
    vim.bo.cindent = true

    -- Never let a formatter rewrite Norm code. Harmless until the lang.c extra
    -- is present; with clang-format installed this is what stops conform.nvim
    -- from reformatting on every save.
    vim.b.autoformat = false

    -- Norm aids: the 80-column limit, and trailing whitespace made visible
    -- (trailing whitespace is itself a Norm error).
    vim.opt_local.colorcolumn = "81"
    vim.opt_local.list = true
    vim.opt_local.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" }

    -- Must run last -- see the note above. The buffer is captured explicitly
    -- because the user may have moved to another one by the time this runs.
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].indentexpr = ""
      end
    end)
  end,
})

-- ══════════════════════════════════════════════════════════════════════════
--  Python : flake8 layout aids
--
--  Indentation needs nothing here: Vim's python ftplugin already sets 4-space
--  soft tabs (PEP 8), and that buffer-local setting wins over LazyVim's global
--  2-space default. Only the visual aids flake8 cares about are added.
--  Linting itself lives in lua/plugins/lang-python.lua.
-- ══════════════════════════════════════════════════════════════════════════
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("flake8_layout", { clear = true }),
  pattern = "python",
  callback = function()
    -- flake8 E501: at most 79 characters, so column 80 is the first illegal one.
    vim.opt_local.colorcolumn = "80"
    -- W291/W293: trailing whitespace and whitespace-only lines.
    vim.opt_local.list = true
    vim.opt_local.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" }
  end,
})
