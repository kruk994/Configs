-- Wires up the norminette diagnostics engine (lua/config/norm42.lua).
--
-- `hardyrafael17/norminette42.nvim` is deliberately NOT used. It has three
-- defects: `maxErrorsToShow` is never copied into its opts (dead option),
-- `getErrors()` emits entries with `message == nil` which :h diagnostic-structure
-- forbids, and it runs on `BufEnter`, so it re-ran on every window switch.
--
-- Commands: :Norm  :NormOn  :NormOff  :NormLimit <n>  :NormDebug
--           :NormIgnore [CODE]  :NormStrict  :NormCount
require("config.norm42").setup({
  limit = 5, -- diagnostics shown per file
  timeout = 3000, -- ms; norminette normally finishes in ~150 ms
  -- Hidden but counted. Temporary (push_swap, 2026-10-05): comments stay in
  -- function bodies while the code is in flux. Empty this list -- or run
  -- :NormStrict -- before pushing; the Norm still forbids them.
  ignore = { "WRONG_SCOPE_COMMENT" },
})

return {}
