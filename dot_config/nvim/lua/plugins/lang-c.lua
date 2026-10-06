-- Machine-specific tuning for the clangd extra.
--
-- The extra itself is imported in lua/config/lazy.lua, NOT here: LazyVim
-- requires extras to be imported between `lazyvim.plugins` and your own
-- plugins, and warns at startup if that order is broken.
--
-- clang-format is intentionally never allowed to run on C buffers: it does not
-- produce Norm-compliant output. lua/config/autocmds.lua sets
-- `vim.b.autoformat = false` for c/cpp, which is what keeps conform.nvim off.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          -- Prefer a clangd that is already on the system.
          --
          -- LazyVim only calls vim.lsp.enable() itself when a server is NOT
          -- handled by mason (lazyvim/plugins/lsp/init.lua:257-266); otherwise
          -- it defers to mason-lspconfig, which downloads its own copy first.
          -- clangd ships with the clang package on Arch and Ubuntu and with the
          -- Xcode command line tools on macOS, so that download is ~100 MB of
          -- duplicate -- and on the 42 machines it eats into the home quota.
          --
          -- Setting mason = false makes LazyVim enable the system binary
          -- directly. When there is no system clangd, mason still installs one.
          mason = vim.fn.executable("clangd") == 0,
        },
      },
    },
  },
  {
    -- No automatic #include insertion. The clangd extra passes
    -- --header-insertion=iwyu, and with completeUnimported accepting a
    -- completion silently adds an #include for the header that DEFINES the
    -- symbol -- on 2026-10-06 that put `#include <bits/posix1_lim.h>` into
    -- push_swap.h: a glibc-internal header that does not exist on macOS, and
    -- without the Norm's `# include` indentation.
    --
    -- A function, not a table: lazy.nvim replaces list-like tables when it
    -- merges opts, so this rewrites the one flag and keeps the extra's others.
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local clangd = opts.servers and opts.servers.clangd
      if clangd and clangd.cmd then
        for i, arg in ipairs(clangd.cmd) do
          if arg:match("^%-%-header%-insertion=") then
            clangd.cmd[i] = "--header-insertion=never"
          end
        end
      end
    end,
  },
}
