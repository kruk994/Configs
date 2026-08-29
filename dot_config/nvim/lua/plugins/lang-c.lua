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
}
