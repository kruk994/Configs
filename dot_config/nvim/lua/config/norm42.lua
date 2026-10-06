-- ══════════════════════════════════════════════════════════════════════════
--  norm42 -- norminette (the 42 style checker) as Neovim diagnostics.
--
--  Everything runs ASYNCHRONOUSLY (vim.fn.jobstart) behind a hard timeout.
--
--  WHY THE TIMEOUT EXISTS -- measured, not guessed:
--  norminette 3.3.59 HANGS FOREVER on a function call without a semicolon.
--  Narrowed down precisely:
--
--      f()      inside if{} / while{} / for{}, or at the end of a function
--                                                  -> hangs indefinitely
--      f();     the same call with the semicolon   -> 116 ms, fine
--      a = 1    assignment without a semicolon     -> 141 ms, fine
--
--  The upstream plugin waited on it synchronously via io.popen and froze the
--  whole editor along with it. Here the process is killed after `timeout` ms
--  and you get a pointed hint instead of a frozen nvim.
--
--  norminette 3.3.60 (verified 2026-08-29) no longer hangs on that input, so
--  this is now a safety net rather than a daily workaround. It stays because
--  the 42 machines pin whatever version the campus image ships, and because a
--  synchronous checker blocking the editor is never acceptable.
--
--  norminette is a STYLE checker, not a syntax checker -- it will never tell
--  you a semicolon is missing. That job belongs to clangd, which the LazyVim
--  lang.c extra installs (see lua/plugins/lang-c.lua). An earlier version of
--  this file ran `cc -fsyntax-only` as a second engine to fill that gap;
--  clangd makes it redundant.
--
--  LINE COUNTER: after every function's closing `}` a virtual text shows its
--  body length, with and without comment-only lines. Pure Lua, no norminette,
--  so it updates as you type. Green: fits. Yellow: too long only because of
--  comments. Red: too long either way.
--
--  Commands: :Norm  :NormOn  :NormOff  :NormLimit <n>  :NormDebug  :NormCount
--            :NormIgnore [CODE]  :NormStrict
--
--  While WRONG_SCOPE_COMMENT is ignored, TOO_MANY_LINES is re-counted without
--  comment-only lines: a function that is too long ONLY because of its
--  comments is treated as ignored too (and counted as such).
--
--  IGNORED CODES are hidden from the diagnostics but still counted: the last
--  shown diagnostic says how many were hidden, so a file is never silently
--  "clean". :NormStrict drops the ignore list -- run it before every push,
--  because an ignored code still fails the evaluation.
-- ══════════════════════════════════════════════════════════════════════════
local M = {}

M.limit = 5 -- how many diagnostics to show
M.timeout = 3000 -- ms
M.enabled = true
M.count = true -- line counter after each function
M.ignore = {} -- set of error codes to hide, e.g. { WRONG_SCOPE_COMMENT = true }

local ns = vim.api.nvim_create_namespace("norm42_norminette")

-- ── log ring buffer, dumped by :NormDebug ─────────────────────────────────
local log = {}
local function note(fmt, ...)
	local ok, s = pcall(string.format, fmt, ...)
	table.insert(log, (ok and s or fmt))
	if #log > 40 then
		table.remove(log, 1)
	end
end

-- ── async runner: jobstart + hard timeout, every call wrapped in pcall ─────
local running = {}

local function run_job(key, cmd, on_done, on_timeout)
	if running[key] then
		note("[%s] skipped -- previous run still in flight", key)
		return
	end
	local lines = {}
	local t0 = vim.loop.hrtime()
	local timer

	local ok, id = pcall(vim.fn.jobstart, cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, d)
			if d then
				vim.list_extend(lines, d)
			end
		end,
		on_stderr = function(_, d)
			if d then
				vim.list_extend(lines, d)
			end
		end,
		on_exit = function(_, code)
			running[key] = nil
			if timer then
				pcall(function()
					timer:stop()
					timer:close()
				end)
			end
			note("[%s] exit=%d %dms lines=%d", key, code, math.floor((vim.loop.hrtime() - t0) / 1e6), #lines)
			local ok2, err = pcall(on_done, lines, code)
			if not ok2 then
				note("[%s] handler error: %s", key, tostring(err))
			end
		end,
	})
	if not ok or id <= 0 then
		note("[%s] jobstart failed: %s", key, tostring(id))
		return
	end
	running[key] = id

	timer = vim.loop.new_timer()
	timer:start(
		M.timeout,
		0,
		vim.schedule_wrap(function()
			if running[key] then
				note("[%s] TIMEOUT after %dms -- killing process", key, M.timeout)
				pcall(vim.fn.jobstop, running[key])
				running[key] = nil
				if on_timeout then
					pcall(on_timeout)
				end
			end
		end)
	)
end

-- norminette embeds ANSI sequences in the message text (e.g. "\27[97m...\27[0m"),
-- which render as garbage inside a diagnostic.
local function strip_ansi(s)
	return (s:gsub("\27%[[%d;]*m", ""))
end

-- Removes comments from one line. `in_block` says whether the line starts
-- inside a /* */ comment; the new state is returned with the text.
-- Does not know about string literals: "a // b" would be cut. Good enough
-- for a line count -- the Norm forbids comments in function bodies anyway.
local function strip_comments(l, in_block)
	local out, i = {}, 1
	while i <= #l do
		if in_block then
			local e = l:find("*/", i, true)
			if not e then
				return table.concat(out), true
			end
			i, in_block = e + 2, false
		else
			local sl = l:find("//", i, true)
			local sb = l:find("/*", i, true)
			if sl and (not sb or sl < sb) then
				table.insert(out, l:sub(i, sl - 1))
				return table.concat(out), false
			elseif sb then
				table.insert(out, l:sub(i, sb - 1))
				i, in_block = sb + 2, true
			else
				table.insert(out, l:sub(i))
				break
			end
		end
	end
	return table.concat(out), in_block
end

-- norminette reports TOO_MANY_LINES on the closing `}` of the function.
-- Walks back to its opening `{` (both in column 0, as the Norm requires) and
-- counts the body without comment-only lines. nil when the braces are not
-- where expected -- the error is then shown as usual.
local NORM_MAX_LINES = 25
local function body_len_without_comments(lines, close)
	if not (lines[close] or ""):match("^}") then
		return nil
	end
	local open
	for i = close - 1, 1, -1 do
		if lines[i]:match("^{") then
			open = i
			break
		elseif lines[i]:match("^}") then
			return nil
		end
	end
	if not open then
		return nil
	end
	local n, in_block = 0, false
	for i = open + 1, close - 1 do
		local code
		code, in_block = strip_comments(lines[i], in_block)
		if lines[i]:match("^%s*$") or code:match("%S") then
			n = n + 1
		end
	end
	return n
end

-- "Error: SPACE_REPLACE_TAB    (line:  16, col:   5):\tFound space when expecting tab"
local PAT = "^Error:%s+(%S+)%s+%(line:%s*(%d+),%s*col:%s*(%d+)%):%s*(.*)$"

---@param buf integer
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
		if vim.fn.executable("norminette") == 0 then
			vim.notify_once(
				"norminette is not in PATH -- Norm diagnostics are off.\nFix: pipx install norminette",
				vim.log.levels.WARN,
				{ title = "norm42" }
			)
			return
		end

		-- List form: no quoting problems with spaces in the path.
		run_job("norminette", { "norminette", name }, function(lines)
			local diags, total, hidden = {}, 0, 0
			local src = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or {}
			for _, line in ipairs(lines) do
				local code, l, c, msg = line:match(PAT)
				local len = code == "TOO_MANY_LINES"
					and M.ignore.WRONG_SCOPE_COMMENT
					and body_len_without_comments(src, tonumber(l))
				if code and M.ignore[code] then
					hidden = hidden + 1
				elseif len and len <= NORM_MAX_LINES then
					note("[norminette] TOO_MANY_LINES at %s: %d lines without comments -> ignored", l, len)
					hidden = hidden + 1
				elseif code then
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
							message = strip_ansi(msg),
						})
					end
				end
			end
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			if total > M.limit and #diags > 0 then
				diags[#diags].message =
					string.format("%s   [+%d more -- fix these and save again]", diags[#diags].message, total - M.limit)
			end
			if hidden > 0 then
				local tag = string.format("[%d ignored -- :NormStrict to show]", hidden)
				if #diags > 0 then
					diags[#diags].message = diags[#diags].message .. "   " .. tag
				else
					-- Nothing left to attach the count to: pin it to line 1.
					table.insert(diags, {
						bufnr = buf,
						lnum = 0,
						col = 0,
						severity = vim.diagnostic.severity.INFO,
						source = "norminette",
						message = "only ignored errors left " .. tag,
					})
				end
			end
			note("[norminette] total=%d ignored=%d", total, hidden)
			pcall(vim.diagnostic.set, ns, buf, diags, { virtual_text = true })
			M.last_total = total
		end, function()
			pcall(vim.diagnostic.reset, ns, buf)
			vim.notify(
				"norminette hung on this file and was killed after "
					.. M.timeout
					.. " ms.\n"
					.. "Most likely cause: A FUNCTION CALL WITHOUT A SEMICOLON.\n"
					.. 'clangd will point at the exact spot ("expected \';\'").',
				vim.log.levels.WARN,
				{ title = "norm42" }
			)
		end)
	end)
	if not ok then
		note("run() error: %s", tostring(err))
	end
end

-- ── line counter ──────────────────────────────────────────────────────────
local ns_count = vim.api.nvim_create_namespace("norm42_count")

-- A function body opens with `{` in column 0 right after its prototype, whose
-- last line ends with `)`. That keeps typedef'd structs in headers
-- (`typedef struct s_x` + `{`) out of the count. Ends with a bare `}`.
function M.count_lines(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns_count, 0, -1)
	if not M.count then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for close, l in ipairs(lines) do
		if l:match("^}%s*$") then
			local raw = body_len_without_comments(lines, close)
			local open
			for i = close - 1, 1, -1 do
				if lines[i]:match("^{") then
					open = i
					break
				end
			end
			if raw and open and open > 1 and lines[open - 1]:match("%)%s*$") then
				local total = close - open - 1
				local hl = total <= NORM_MAX_LINES and "DiagnosticOk"
					or raw <= NORM_MAX_LINES and "DiagnosticWarn"
					or "DiagnosticError"
				pcall(vim.api.nvim_buf_set_extmark, buf, ns_count, close - 1, 0, {
					virt_text = { { string.format("  %d lines · %d without comments", total, raw), hl } },
					virt_text_pos = "eol",
				})
			end
		end
	end
end

function M.clear(buf)
	pcall(vim.diagnostic.reset, ns, buf)
end

function M.setup(opts)
	opts = opts or {}
	for _, k in ipairs({ "limit", "timeout" }) do
		if opts[k] ~= nil then
			M[k] = opts[k]
		end
	end
	for _, code in ipairs(opts.ignore or {}) do
		M.ignore[code] = true
	end

	-- BufReadPost/BufWritePost, NOT BufEnter: BufEnter fires on every window
	-- and buffer switch, so norminette ran several times per glance at a file.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
		group = vim.api.nvim_create_augroup("Norm42", { clear = true }),
		pattern = { "*.c", "*.h" },
		callback = function(ev)
			M.run(ev.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = vim.api.nvim_create_augroup("Norm42Count", { clear = true }),
		pattern = { "*.c", "*.h" },
		callback = function(ev)
			pcall(M.count_lines, ev.buf)
		end,
	})

	-- Catch a buffer that was already loaded before the autocmd existed
	-- (e.g. `nvim ft_split.c`).
	local cur = vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_get_name(cur):match("%.[ch]$") then
		vim.schedule(function()
			M.run(cur)
			pcall(M.count_lines, cur)
		end)
	end

	local function cmd(nm, fn, o)
		vim.api.nvim_create_user_command(nm, fn, o or {})
	end
	cmd("Norm", function()
		M.run(vim.api.nvim_get_current_buf())
	end, { desc = "norminette on the current buffer" })
	cmd("NormOn", function()
		M.enabled = true
		M.run(vim.api.nvim_get_current_buf())
	end, { desc = "enable Norm diagnostics" })
	cmd("NormOff", function()
		M.enabled = false
		M.clear(vim.api.nvim_get_current_buf())
	end, { desc = "disable Norm diagnostics" })
	cmd("NormLimit", function(o)
		M.limit = tonumber(o.args) or M.limit
		M.run(vim.api.nvim_get_current_buf())
	end, { nargs = 1, desc = "change how many Norm errors are shown" })
	cmd("NormIgnore", function(o)
		if o.args ~= "" then
			M.ignore[o.args] = not M.ignore[o.args] or nil
			M.run(vim.api.nvim_get_current_buf())
		end
		local codes = vim.tbl_keys(M.ignore)
		table.sort(codes)
		vim.notify(
			#codes > 0 and ("ignored: " .. table.concat(codes, ", ")) or "ignoring nothing",
			vim.log.levels.INFO,
			{ title = "norm42" }
		)
	end, { nargs = "?", desc = "toggle hiding a norminette error code; no arg lists them" })
	cmd("NormCount", function()
		M.count = not M.count
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_get_name(b):match("%.[ch]$") then
				pcall(M.count_lines, b)
			end
		end
	end, { desc = "toggle the per-function line counter" })
	cmd("NormStrict", function()
		M.ignore = {}
		M.run(vim.api.nvim_get_current_buf())
		vim.notify("ignoring nothing -- full Norm", vim.log.levels.INFO, { title = "norm42" })
	end, { desc = "show every norminette error (clear the ignore list)" })
	cmd("NormDebug", function()
		local out = { "norm42 -- recent runs:", "" }
		vim.list_extend(out, log)
		table.insert(out, "")
		table.insert(out, ("limit=%d timeout=%dms"):format(M.limit, M.timeout))
		table.insert(out, "ignore: " .. table.concat(vim.tbl_keys(M.ignore), ", "))
		vim.api.nvim_echo({ { table.concat(out, "\n") } }, true, {})
	end, { desc = "what happened on the last norminette runs" })
end

return M
