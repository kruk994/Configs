-- ══════════════════════════════════════════════════════════════════════════
--  norm42 — dwa niezalezne zrodla diagnostyk dla plikow 42:
--
--    1. norminette      -> styl (norma). NIE wykrywa bledow skladni.
--    2. cc -fsyntax-only -> skladnia. To ONO mowi "expected ';' before ..."
--
--  norminette nigdy nie powie Ci, ze zapomniales srednika — to nie jej rola.
--  Powie najwyzej cos posredniego (np. RETURN_PARENTHESIS). Dlatego drugi
--  silnik: kompilator uruchamiany wylacznie do sprawdzenia skladni.
--
--  Wszystko chodzi ASYNCHRONICZNIE (vim.fn.jobstart) z twardym timeoutem.
--  Zaden zewnetrzny proces nie moze juz zamrozic Neovima, nawet gdyby sie
--  zawiesil. Kazde wywolanie jest opakowane w pcall — blad w tym pliku nie
--  moze wywrocic autocmd i wpasc w petle powtorzen.
-- ══════════════════════════════════════════════════════════════════════════
local M = {}

M.limit = 5                -- ile diagnostyk pokazujemy na zrodlo
M.timeout = 3000           -- ms; norminette normalnie konczy w ~150 ms
M.enabled = true
M.syntax = true            -- drugi silnik: cc -fsyntax-only
M.cc = nil                 -- nil = wykryj (cc, potem clang, potem gcc)

local ns_norm = vim.api.nvim_create_namespace("norm42_norminette")
local ns_syn = vim.api.nvim_create_namespace("norm42_syntax")

-- ── dziennik do :NormDebug ────────────────────────────────────────────────
local log = {}
local function note(fmt, ...)
	local ok, s = pcall(string.format, fmt, ...)
	table.insert(log, (ok and s or fmt))
	if #log > 40 then
		table.remove(log, 1)
	end
end

-- ── wspolny biegacz: async + timeout + pcall ──────────────────────────────
local running = {}

local function run_job(key, cmd, on_done, on_timeout)
	if running[key] then
		note("[%s] pomijam — poprzedni przebieg jeszcze trwa", key)
		return
	end
	local lines = {}
	local t0 = vim.loop.hrtime()
	local timer

	local ok, id = pcall(vim.fn.jobstart, cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, d)
			if d then vim.list_extend(lines, d) end
		end,
		on_stderr = function(_, d)
			if d then vim.list_extend(lines, d) end
		end,
		on_exit = function(_, code)
			running[key] = nil
			if timer then
				pcall(function() timer:stop(); timer:close() end)
			end
			local ms = (vim.loop.hrtime() - t0) / 1e6
			note("[%s] kod=%d czas=%dms linii=%d", key, code, math.floor(ms), #lines)
			local ok2, err = pcall(on_done, lines, code)
			if not ok2 then
				note("[%s] BLAD w obrobce: %s", key, tostring(err))
			end
		end,
	})
	if not ok or id <= 0 then
		note("[%s] jobstart padl: %s", key, tostring(id))
		return
	end
	running[key] = id

	-- twardy timeout: zawieszony proces nie ma prawa zamrozic edytora
	timer = vim.loop.new_timer()
	timer:start(M.timeout, 0, vim.schedule_wrap(function()
		if running[key] then
			note("[%s] TIMEOUT po %dms — zabijam proces", key, M.timeout)
			pcall(vim.fn.jobstop, running[key])
			running[key] = nil
			if on_timeout then
				pcall(on_timeout)
			end
		end
	end))
end

-- norminette wstawia sekwencje ANSI w tresc komunikatu (np. "\27[97m...\27[0m").
-- W diagnostyce wygladaja jak smieci, wiec je zdejmujemy.
local function strip_ansi(s)
	return (s:gsub("\27%[[%d;]*m", ""))
end

local function put(ns, buf, diags, total)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if total > M.limit and #diags > 0 then
		diags[#diags].message = string.format("%s   [+%d dalszych]",
			diags[#diags].message, total - M.limit)
	end
	pcall(vim.diagnostic.set, ns, buf, diags, { virtual_text = true })
end

-- ── 1. norminette (styl) ──────────────────────────────────────────────────
local NORM_PAT = "^Error:%s+(%S+)%s+%(line:%s*(%d+),%s*col:%s*(%d+)%):%s*(.*)$"

function M.run_norm(buf, name)
	if vim.fn.executable("norminette") == 0 then
		vim.notify_once("norminette nie jest w PATH.\nNapraw: pipx install norminette",
			vim.log.levels.WARN, { title = "norm42" })
		return
	end
	run_job("norminette", { "norminette", name }, function(lines)
		local diags, total = {}, 0
		for _, line in ipairs(lines) do
			local code, l, c, msg = line:match(NORM_PAT)
			if code then
				total = total + 1
				if #diags < M.limit then
					local ln = math.max(tonumber(l) - 1, 0)
					local co = math.max(tonumber(c) - 1, 0)
					table.insert(diags, {
						bufnr = buf, lnum = ln, end_lnum = ln, col = co, end_col = co + 1,
						severity = vim.diagnostic.severity.ERROR,
						source = "norminette", code = code, message = strip_ansi(msg),
					})
				end
			end
		end
		put(ns_norm, buf, diags, total)
	end, function()
		-- norminette 3.3.59 WISI w nieskonczonosc na wywolaniu funkcji bez
		-- srednika (zmierzone: `f()` bez `;` w if/while/for albo na koncu
		-- funkcji — przypisanie bez srednika juz nie). Wczesniej plugin czekal
		-- na nia synchronicznie przez io.popen, wiec zawieszal caly edytor.
		-- Teraz proces jest zabijany, a Ty dostajesz konkretna podpowiedz.
		pcall(vim.diagnostic.reset, ns_norm, buf)
		vim.notify(
			"norminette zawiesila sie na tym pliku i zostala ubita po "
				.. M.timeout .. " ms.\n"
				.. "Najczestsza przyczyna: WYWOLANIE FUNKCJI BEZ SREDNIKA.\n"
				.. "Dokladne miejsce masz w diagnostykach kompilatora (\"expected ';'\").",
			vim.log.levels.WARN,
			{ title = "norm42" }
		)
	end)
end

-- ── 2. cc -fsyntax-only (skladnia) ────────────────────────────────────────
-- "plik.c:18:27: error: expected ';' before 'while'"
-- "repro.c:13:20: error: expected ';' before '}' token"
-- "repro.c:1:10: fatal error: libft.h: No such file or directory"
local CC_PAT = "^(.-):(%d+):(%d+):%s+(.-):%s+(.*)$"
local SEV = {
	["error"] = vim.diagnostic.severity.ERROR,
	["fatal error"] = vim.diagnostic.severity.ERROR,
	["warning"] = vim.diagnostic.severity.WARN,
	["note"] = vim.diagnostic.severity.HINT,
}

local function pick_cc()
	if M.cc then
		return M.cc
	end
	for _, c in ipairs({ "cc", "clang", "gcc" }) do
		if vim.fn.executable(c) == 1 then
			M.cc = c
			return c
		end
	end
	return nil
end

function M.run_syntax(buf, name)
	local cc = pick_cc()
	if not cc then
		return
	end
	local dir = vim.fn.fnamemodify(name, ":h")
	-- UWAGA: tylko flagi, ktore rozumieja I clang, I gcc.
	-- `-fno-color-diagnostics` jest wylacznie clangowe, a `-fno-diagnostics-show-caret`
	-- wylacznie gccowe — kazda z nich wywala cale wywolanie na tym drugim.
	-- `-fdiagnostics-color=never` znaja oba.
	local cmd = { cc, "-fsyntax-only", "-Wall", "-Wextra",
		"-fdiagnostics-color=never", "-I", dir, "-I", dir .. "/..", name }
	run_job("cc", cmd, function(lines)
		local all, total = {}, 0
		for _, line in ipairs(lines) do
			local f, l, c, sev, msg = line:match(CC_PAT)
			-- interesuja nas tylko komunikaty o TYM pliku i tylko bledy/ostrzezenia
			if f and SEV[sev] and vim.fn.fnamemodify(f, ":t") == vim.fn.fnamemodify(name, ":t") then
				if sev ~= "note" then
					total = total + 1
					local ln = math.max(tonumber(l) - 1, 0)
					local co = math.max(tonumber(c) - 1, 0)
					table.insert(all, {
						bufnr = buf, lnum = ln, end_lnum = ln, col = co, end_col = co + 1,
						severity = SEV[sev], source = cc, message = strip_ansi(msg),
					})
				end
			end
		end
		-- Kolejnosc ma znaczenie, bo pokazujemy tylko M.limit sztuk.
		-- Blad skladni ("expected ';'") to zwykle PRZYCZYNA reszty komunikatow,
		-- wiec ma isc na gore — inaczej wypadlby poza limit i zostalbys
		-- z lawina skutkow zamiast zrodla.
		local function rank(d)
			if d.message:match("^expected")
				or d.message:match("before%s+'?[%w_}%]%)]+'?%s*token")
				or d.message:match("^unterminated")
				or d.message:match("^missing") then
				return 0
			end
			if d.severity == vim.diagnostic.severity.ERROR then
				return 1
			end
			return 2
		end
		table.sort(all, function(a, b)
			local ra, rb = rank(a), rank(b)
			if ra ~= rb then
				return ra < rb
			end
			return a.lnum < b.lnum
		end)
		local diags = {}
		for i = 1, math.min(#all, M.limit) do
			diags[i] = all[i]
		end
		put(ns_syn, buf, diags, total)
	end)
end

-- ── wspolne wejscie ───────────────────────────────────────────────────────
function M.run(buf)
	if not M.enabled then
		return
	end
	local ok, err = pcall(function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local name = vim.api.nvim_buf_get_name(buf)
		if name == "" or vim.fn.filereadable(name) == 0 then
			return
		end
		M.run_norm(buf, name)
		if M.syntax then
			M.run_syntax(buf, name)
		end
	end)
	if not ok then
		note("run() BLAD: %s", tostring(err))
	end
end

function M.clear(buf)
	pcall(vim.diagnostic.reset, ns_norm, buf)
	pcall(vim.diagnostic.reset, ns_syn, buf)
end

function M.setup(opts)
	opts = opts or {}
	for _, k in ipairs({ "limit", "timeout", "syntax", "cc" }) do
		if opts[k] ~= nil then
			M[k] = opts[k]
		end
	end

	local grp = vim.api.nvim_create_augroup("Norm42", { clear = true })
	-- BufReadPost, a NIE BufEnter: BufEnter odpala sie przy kazdym przejsciu
	-- miedzy oknami i buforami.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
		group = grp,
		pattern = { "*.c", "*.h" },
		callback = function(ev)
			M.run(ev.buf)
		end,
	})

	local cur = vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_get_name(cur):match("%.[ch]$") then
		vim.schedule(function() M.run(cur) end)
	end

	local function cmd(nm, fn, o)
		vim.api.nvim_create_user_command(nm, fn, o or {})
	end
	cmd("Norm", function() M.run(vim.api.nvim_get_current_buf()) end,
		{ desc = "norminette + skladnia na biezacym buforze" })
	cmd("NormOff", function() M.enabled = false; M.clear(0) end, { desc = "wylacz" })
	cmd("NormOn", function() M.enabled = true; M.run(0) end, { desc = "wlacz" })
	cmd("NormLimit", function(o) M.limit = tonumber(o.args) or M.limit; M.run(0) end,
		{ nargs = 1, desc = "limit pokazywanych diagnostyk" })
	cmd("NormSyntax", function() M.syntax = not M.syntax; M.clear(0); M.run(0)
		vim.notify("sprawdzanie skladni: " .. tostring(M.syntax), vim.log.levels.INFO,
			{ title = "norm42" }) end, { desc = "przelacz cc -fsyntax-only" })
	cmd("NormDebug", function()
		local out = { "norm42 — dziennik ostatnich przebiegow:", "" }
		vim.list_extend(out, log)
		table.insert(out, "")
		table.insert(out, ("limit=%d timeout=%dms syntax=%s cc=%s")
			:format(M.limit, M.timeout, tostring(M.syntax), tostring(M.cc)))
		vim.api.nvim_echo({ { table.concat(out, "\n") } }, true, {})
	end, { desc = "co sie stalo przy ostatnich przebiegach" })
end

return M
