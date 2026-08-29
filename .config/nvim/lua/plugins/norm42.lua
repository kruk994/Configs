-- ══════════════════════════════════════════════════════════════════════════
--  norm42 — norminette jako diagnostyki, z TWARDYM limitem błędów.
--
--  Dlaczego własny silnik, a nie opcja w norminette42.nvim:
--  1. `setup()` pluginu nigdy nie kopiuje `maxErrorsToShow` z argumentów do
--     swoich `opts` (lua/norminette/init.lua) — ta opcja jest martwa.
--  2. Nawet gdyby działała, nie zmniejsza liczby diagnostyk: `getErrors()`
--     zwraca `nil` jako `message` dla nadmiarowych wpisów, ale wpisy i tak
--     lądują w tabeli. Na pliku z 32 błędami daje to 32 diagnostyki, z czego
--     27 z `message == nil` — a `:h diagnostic-structure` wymaga stringa.
--  3. Plugin czyta wyjście przez `io.popen` i nie sprawdza, czy binarka
--     w ogóle istnieje; przy jej braku cicho czyści diagnostyki.
-- ══════════════════════════════════════════════════════════════════════════
local M = {}

M.limit = 5
M.enabled = true

local ns = vim.api.nvim_create_namespace("norm42")
local busy = false

-- "Error: SPACE_REPLACE_TAB    (line:  16, col:   5):\tFound space when expecting tab"
local PAT = "^Error:%s+(%S+)%s+%(line:%s*(%d+),%s*col:%s*(%d+)%):%s*(.*)$"

---@param buf integer
function M.run(buf)
	if not M.enabled or busy then
		return
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" or vim.fn.filereadable(name) == 0 then
		return
	end
	if vim.fn.executable("norminette") == 0 then
		vim.notify_once(
			"norminette nie jest w PATH — diagnostyki normy nie beda dzialac.\n"
				.. "Napraw: pipx install norminette",
			vim.log.levels.WARN,
			{ title = "norm42" }
		)
		return
	end

	busy = true
	-- forma listowa: zero problemow z cudzyslowami i spacjami w sciezce
	local out = vim.fn.systemlist({ "norminette", name })
	busy = false

	local diags, total = {}, 0
	for _, line in ipairs(out) do
		local code, l, c, msg = line:match(PAT)
		if code then
			total = total + 1
			if #diags < M.limit then
				local ln = math.max(tonumber(l) - 1, 0)
				local co = math.max(tonumber(c) - 1, 0)
				table.insert(diags, {
					bufnr = buf,
					lnum = ln,
					end_lnum = ln,
					col = co,
					end_col = co + 1,
					severity = vim.diagnostic.severity.ERROR,
					source = "norminette",
					code = code,
					message = msg,
				})
			end
		end
	end

	if total > M.limit and #diags > 0 then
		diags[#diags].message = string.format(
			"%s   [+%d dalszych bledow — popraw te i zapisz ponownie]",
			diags[#diags].message,
			total - M.limit
		)
	end

	vim.diagnostic.set(ns, buf, diags, { virtual_text = true })
	return total
end

function M.clear(buf)
	vim.diagnostic.reset(ns, buf)
end

function M.setup(opts)
	opts = opts or {}
	M.limit = opts.limit or M.limit

	local grp = vim.api.nvim_create_augroup("Norm42", { clear = true })

	-- BufReadPost, a NIE BufEnter: BufEnter odpala sie przy kazdym przejsciu
	-- miedzy oknami i buforami, wiec norminette chodzila po kilka razy na
	-- jedno spojrzenie na plik. To najbardziej prawdopodobne zrodlo zapetlenia.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
		group = grp,
		pattern = { "*.c", "*.h" },
		callback = function(ev)
			M.run(ev.buf)
		end,
	})

	-- Gdyby plik byl juz wczytany, zanim zdazylismy zalozyc autocmd
	-- (np. `nvim ft_split.c`), doganiamy go recznie.
	local cur = vim.api.nvim_get_current_buf()
	local nm = vim.api.nvim_buf_get_name(cur)
	if nm:match("%.[ch]$") then
		vim.schedule(function()
			M.run(cur)
		end)
	end

	vim.api.nvim_create_user_command("Norm", function()
		local n = M.run(vim.api.nvim_get_current_buf())
		if n == 0 then
			vim.notify("norminette: OK", vim.log.levels.INFO, { title = "norm42" })
		elseif n then
			vim.notify(("norminette: %d bledow (pokazuje %d)"):format(n, math.min(n, M.limit)),
				vim.log.levels.WARN, { title = "norm42" })
		end
	end, { desc = "norminette na biezacym buforze" })

	vim.api.nvim_create_user_command("NormOff", function()
		M.enabled = false
		M.clear(nil)
	end, { desc = "wylacz diagnostyki normy" })

	vim.api.nvim_create_user_command("NormOn", function()
		M.enabled = true
		M.run(vim.api.nvim_get_current_buf())
	end, { desc = "wlacz diagnostyki normy" })

	vim.api.nvim_create_user_command("NormLimit", function(o)
		M.limit = tonumber(o.args) or M.limit
		M.run(vim.api.nvim_get_current_buf())
	end, { nargs = 1, desc = "zmien limit pokazywanych bledow normy" })
end

return M
