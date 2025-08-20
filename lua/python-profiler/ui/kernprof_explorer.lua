local M = {}
local global_state = require("python-profiler.state")

local state = {
	bufnr = nil,
	winnr = nil,
	sort_by = "time",
	file_lines = {},
}

local function calculate_file_stats(profiles, total_time)
	local stats = {}

	local tool_profiles = profiles.kernprof or {}
	for filepath, data in pairs(tool_profiles) do
		if not stats[filepath] then
			stats[filepath] = {
				path = filepath,
				time = 0,
				percent = 0,
				functions = {},
				tools = {},
				annotated = false,
			}
		end

		local file_time = 0

		if data.functions then
			for _, func in ipairs(data.functions) do
				file_time = file_time + (func.total_time or 0)
				table.insert(stats[filepath].functions, {
					name = func.name,
					time = func.total_time or 0,
					line = func.start_line,
				})
			end
		end

		if data.lines and #stats[filepath].functions == 0 then
			for _, line_data in pairs(data.lines) do
				file_time = file_time + (line_data.time or 0)
			end
		end

		stats[filepath].time = stats[filepath].time + file_time
		stats[filepath].percent = (file_time / (total_time.kernprof or 1)) * 100
		table.insert(stats[filepath].tools, "kernprof")

		local bufnr = vim.fn.bufnr(filepath)
		if bufnr ~= -1 then
			stats[filepath].annotated = vim.api.nvim_buf_is_loaded(bufnr)
		end
	end

	return stats
end

local function render_bar(percent, width)
	local filled = math.floor((percent / 100) * width)
	return string.rep("█", filled) .. string.rep("░", width - filled)
end

local function fit_text(text, width)
	if #text <= width then
		return text .. string.rep(" ", width - #text)
	else
		return text:sub(1, width - 1) .. "…"
	end
end

local function render_content()
	local lines = {}
	local highlights = {}
	state.file_lines = {}

	local win_width = vim.api.nvim_win_get_width(state.winnr or 0)
	local content_width = math.max(40, win_width - 4)

	local file_stats = calculate_file_stats(global_state.profiles, global_state.total_time)
	local sorted_files = {}
	for _, stat in pairs(file_stats) do
		table.insert(sorted_files, stat)
	end

	table.sort(sorted_files, function(a, b)
		if state.sort_by == "time" then
			return a.time > b.time
		elseif state.sort_by == "percent" then
			return a.percent > b.percent
		else
			return a.path < b.path
		end
	end)

	local total_files = #sorted_files

	local total_time_sum = global_state.total_time.kernprof or 0

	table.insert(lines, "---")
	table.insert(highlights, { group = "Comment", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, "Profile Overview")
	table.insert(highlights, { group = "Title", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, string.format("Total time: %.3fs", total_time_sum))
	table.insert(highlights, { group = "Number", line = #lines - 1, col_start = 12, col_end = -1 })

	table.insert(lines, string.format("Files profiled: %d", total_files))
	table.insert(highlights, { group = "Number", line = #lines - 1, col_start = 16, col_end = -1 })

	table.insert(lines, "---")
	table.insert(highlights, { group = "Comment", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(highlights, { group = "Comment", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, "File List")
	table.insert(highlights, { group = "Title", line = #lines - 1, col_start = 0, col_end = -1 })

	local bar_width = math.min(15, math.floor(content_width * 0.3))
	local name_width = content_width - bar_width - 12

	for i, file in ipairs(sorted_files) do
		local filename = vim.fn.fnamemodify(file.path, ":t")
		local bar = render_bar(file.percent, bar_width)

		local line_text = string.format("- %s %s %5.1f%%", fit_text(filename, name_width), bar, file.percent)

		table.insert(lines, line_text)

		table.insert(
			highlights,
			{ group = "Directory", line = #lines - 1, col_start = 2, col_end = 2 + #fit_text(filename, name_width) }
		)

		local percent_start = #line_text - 6
		local percent_group = file.percent > 50 and "ErrorMsg" or file.percent > 20 and "WarningMsg" or "String"
		table.insert(highlights, { group = percent_group, line = #lines - 1, col_start = percent_start, col_end = -1 })

		state.file_lines[#lines] = file.path
	end
	table.insert(lines, "---")
	table.insert(highlights, { group = "Comment", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, "")
	table.insert(lines, "Keys: <CR> jump │ c clear")
	table.insert(highlights, { group = "Special", line = #lines - 1, col_start = 0, col_end = -1 })

	table.insert(lines, "      s sort │ q quit")
	table.insert(highlights, { group = "Special", line = #lines - 1, col_start = 0, col_end = -1 })

	return lines, highlights
end

local function create_buffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_name(buf, "Python Profiler - Kernprof")
	return buf
end

local function get_selected_file()
	local line = vim.api.nvim_win_get_cursor(state.winnr)[1]
	return state.file_lines[line]
end

local function move_cursor_to_file(direction)
	local current_line = vim.api.nvim_win_get_cursor(state.winnr)[1]
	local file_line_nums = {}

	for line_num, _ in pairs(state.file_lines) do
		table.insert(file_line_nums, line_num)
	end
	table.sort(file_line_nums)

	if #file_line_nums == 0 then
		return
	end

	local target_line
	if direction > 0 then
		for _, line_num in ipairs(file_line_nums) do
			if line_num > current_line then
				target_line = line_num
				break
			end
		end
		target_line = target_line or file_line_nums[1]
	else
		for i = #file_line_nums, 1, -1 do
			if file_line_nums[i] < current_line then
				target_line = file_line_nums[i]
				break
			end
		end
		target_line = target_line or file_line_nums[#file_line_nums]
	end

	vim.api.nvim_win_set_cursor(state.winnr, { target_line, 0 })
end

local function setup_keymaps()
	local opts = { buffer = state.bufnr, silent = true }

	vim.keymap.set("n", "j", function()
		move_cursor_to_file(1)
	end, opts)
	vim.keymap.set("n", "k", function()
		move_cursor_to_file(-1)
	end, opts)
	vim.keymap.set("n", "<Down>", function()
		move_cursor_to_file(1)
	end, opts)
	vim.keymap.set("n", "<Up>", function()
		move_cursor_to_file(-1)
	end, opts)

	vim.keymap.set("n", "h", "<Nop>", opts)
	vim.keymap.set("n", "l", "<Nop>", opts)
	vim.keymap.set("n", "<Left>", "<Nop>", opts)
	vim.keymap.set("n", "<Right>", "<Nop>", opts)

	vim.keymap.set("n", "<CR>", function()
		local filepath = get_selected_file()
		if filepath then
			vim.cmd("wincmd p")
			vim.cmd("edit " .. filepath)
		end
	end, opts)

	vim.keymap.set("n", "s", function()
		local modes = { "time", "percent", "name" }
		local current = vim.fn.index(modes, state.sort_by)
		state.sort_by = modes[((current + 1) % #modes) + 1]
		M.refresh()
	end, opts)

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(state.winnr, true)
		state.winnr = nil
		state.bufnr = nil
	end, opts)

	vim.keymap.set("n", "c", function()
		local filepath = get_selected_file()
		if filepath then
			vim.notify("Clear: " .. filepath)
		end
	end, opts)
end

function M.refresh()
	if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
		return
	end

	local current_line = vim.api.nvim_win_get_cursor(state.winnr)[1]
	local lines, highlights = render_content()

	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", false)

	local ns = vim.api.nvim_create_namespace("python_profiler_ui")
	vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(state.bufnr, ns, hl.group, hl.line, hl.col_start, hl.col_end)
	end

	if state.file_lines[current_line] then
		vim.api.nvim_win_set_cursor(state.winnr, { current_line, 0 })
	else
		for line_num, _ in pairs(state.file_lines) do
			vim.api.nvim_win_set_cursor(state.winnr, { line_num, 0 })
			break
		end
	end
end

function M.show(profiles, total_time)
	if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
		M.refresh()
		return
	end

	state.bufnr = create_buffer()

	local current_width = vim.o.columns
	local split_width = math.min(60, math.floor(current_width * 0.4))

	vim.cmd("vsplit")
	state.winnr = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.winnr, state.bufnr)
	vim.api.nvim_win_set_width(state.winnr, split_width)

	vim.wo[state.winnr].cursorline = true
	vim.wo[state.winnr].number = false
	vim.wo[state.winnr].relativenumber = false
	vim.wo[state.winnr].signcolumn = "no"
	vim.wo[state.winnr].wrap = false

	setup_keymaps()
	M.refresh()

	for line_num, _ in pairs(state.file_lines) do
		vim.api.nvim_win_set_cursor(state.winnr, { line_num, 0 })
		break
	end
end

function M.hide()
	if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
		vim.api.nvim_win_close(state.winnr, true)
		state.winnr = nil
		state.bufnr = nil
	end
end

function M.toggle()
	if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
		M.hide()
	else
		M.show()
	end
end

function M.is_open()
	return state.winnr and vim.api.nvim_win_is_valid(state.winnr)
end

return M
