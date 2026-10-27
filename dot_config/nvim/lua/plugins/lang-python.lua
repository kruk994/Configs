-- Python for the 42 Common Core (M2 Python modules, A-Maze-ing): flake8 and
-- mypy as Neovim diagnostics -- the Python counterpart of norm42.
--
-- Both subjects require: "Your code must respect the flake8 linter standards"
-- and type hints checked with mypy (P00 ex7, every function from P01 on).
-- Evaluators run both, so a file is done when both are silent.
--
-- WHY nvim-lint and not the LazyVim lang.python extra:
-- the extra brings an LSP (pyright) and ruff via mason. ruff's rule set is not
-- flake8's, and its formatter targets 88 columns while flake8 stops at 79, so
-- format-on-save would produce code that flake8 then rejects. nvim-lint is
-- already part of LazyVim and runs the very binaries the evaluator uses.
--
-- WHEN they run: on open, on save and when leaving insert mode (LazyVim's
-- nvim-lint events). flake8 reads the BUFFER (stdin), so it is live; mypy
-- reads the FILE on disk, so its diagnostics follow the last :w.
--
-- Binaries come from the system (pacman/apt: flake8, mypy; or pipx). A missing
-- one is skipped silently instead of raising an error on every save.
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        python = { "flake8", "mypy" },
      },
      linters = {
        flake8 = {
          condition = function()
            return vim.fn.executable("flake8") == 1
          end,
        },
        mypy = {
          condition = function()
            return vim.fn.executable("mypy") == 1
          end,
          -- Stricter than a bare `mypy file.py`: an unannotated function is
          -- otherwise NOT checked at all and passes silently. P01 requires
          -- hints on every function and method, so a missing one should show.
          -- In P00 (hints optional before ex7) these are reminders, not errors
          -- the evaluator would raise.
          prepend_args = { "--disallow-untyped-defs", "--disallow-incomplete-defs" },
        },
      },
    },
  },
}
