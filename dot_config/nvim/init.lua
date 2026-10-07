-- bootstrap lazy.nvim, LazyVim and your plugins
--
-- On Omarchy this file is shipped by Omarchy's LazyVim starter and is NOT
-- applied from here (see .chezmoiignore). On macOS and the 42 machines nothing
-- else provides it: without it nvim never loads lua/config/lazy.lua, and
-- `:Lazy` does not exist (E492). Found on the M4 Air, 2026-10-07.
require("config.lazy")
