-- LazyVim's official C/C++ language extra: clangd (real syntax and semantic
-- errors, completion, go-to-definition, hover) plus clang-format.
--
-- Imported as a plugin spec rather than added to lazyvim.json because LazyVim
-- writes to that file itself (news checksums); managing it from chezmoi would
-- mean fighting it on every update. The two routes are equivalent.
--
-- clang-format is intentionally NEVER allowed to run on C buffers: it does not
-- produce Norm-compliant output. lua/config/autocmds.lua sets
-- `vim.b.autoformat = false` for c/cpp, which is what keeps conform.nvim off.
return {
  { import = "lazyvim.plugins.extras.lang.clangd" },

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
