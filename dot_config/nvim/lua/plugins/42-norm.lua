-- Wires up the norminette diagnostics engine (lua/config/norm42.lua).
--
-- `hardyrafael17/norminette42.nvim` is deliberately NOT used. It has three
-- defects: `maxErrorsToShow` is never copied into its opts (dead option),
-- `getErrors()` emits entries with `message == nil` which :h diagnostic-structure
-- forbids, and it runs on `BufEnter`, so it re-ran on every window switch.
--
-- Commands: :Norm  :NormOn  :NormOff  :NormLimit <n>  :NormDebug
require("config.norm42").setup({
  limit = 5, -- diagnostics shown per file
  timeout = 3000, -- ms; norminette normally finishes in ~150 ms
})

return {}
