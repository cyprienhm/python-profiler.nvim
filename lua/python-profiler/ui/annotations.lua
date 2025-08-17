local highlights = require("python-profiler.ui.highlights")
local paths = require("python-profiler.utils.paths")

local M = {}

local function make_bar(ratio, width, tool)
	local filled = math.floor(ratio * width)
	if tool == "kernprof" then
		-- Line profiler uses solid blocks
		return string.rep("█", filled) .. string.rep("░", width - filled)
	else
		-- Call stack profiler uses gradient blocks
		return string.rep("▉", filled) .. string.rep("▊", width - filled)
	end
end

local function get_tool_prefix(tool)
	if tool == "kernprof" then
		return "[L]" -- Line profiler
	else
		return "[C]" -- Call stack profiler
	end
end

function M.annotate_lines(filepath, tool, profiles, total_time, ns)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local file_data = profiles[tool][filepath]
	if not file_data then
		return
	end

	-- Handle both old format (direct lines) and new format (with .lines)
	local lines = file_data.lines or file_data
	if not lines then
		return
	end

	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, ns[tool], 0, -1)

	-- First annotate function definitions
	if file_data.functions then
		local prefix = get_tool_prefix(tool)
		for _, func in ipairs(file_data.functions) do
			local func_ratio = func.total_time / total_time[tool]
			local highlight_group = highlights.get_highlight_group(func_ratio)
			vim.api.nvim_buf_set_extmark(bufnr, ns[tool], func.start_line - 1, 0, {
				virt_text = {
					{ make_bar(func_ratio, 15, tool) .. " ", highlight_group },
					{
						string.format("%s %s: %.3fs (%.1f%% total)", prefix, func.name, func.total_time, func_ratio * 100),
						highlight_group,
					},
				},
				virt_text_pos = "eol",
			})
		end
	end

	-- Then annotate individual lines
	local prefix = get_tool_prefix(tool)
	for line, t in pairs(lines) do
		-- Regular line annotation
		local bar_ratio = (t.percent_in_function and t.percent_in_function / 100) or (t.time / total_time[tool])
		local total_ratio = t.time / total_time[tool]
		local highlight_group = highlights.get_highlight_group(bar_ratio)

		-- Build rich annotation text
		local function_info = t.function_name and (" [" .. t.function_name .. "]") or ""
		local percent_func = t.percent_in_function and string.format("%.1f%% func", t.percent_in_function) or ""
		local percent_total = string.format("%.1f%% total", total_ratio * 100)
		local per_hit_info = t.time_per_hit and string.format("%.3fs/hit", t.time_per_hit) or ""

		local info_parts = {}
		if percent_func ~= "" then
			table.insert(info_parts, percent_func)
		end
		table.insert(info_parts, percent_total)
		local percent_info = table.concat(info_parts, ", ")

		local timing_parts = { string.format("%.3fs", t.time) }
		if per_hit_info ~= "" then
			table.insert(timing_parts, per_hit_info)
		end
		local timing_info = table.concat(timing_parts, " ")

		vim.api.nvim_buf_set_extmark(bufnr, ns[tool], line - 1, 0, {
			virt_text = {
				{ make_bar(bar_ratio, 10, tool) .. " ", highlight_group },
				{
					string.format("%s (%s) -- %d calls %s%s", timing_info, percent_info, t.count, prefix, function_info),
					highlight_group,
				},
			},
			virt_text_pos = "eol",
		})
	end
end

function M.annotate_all_open_buffers(tool, profiles, total_time, ns)
	for filepath, _ in pairs(profiles[tool]) do
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			M.annotate_lines(filepath, tool, profiles, total_time, ns)
		end
	end
end

function M.clear_annotations(tool, profiles, ns)
	for filepath, _ in pairs(profiles[tool]) do
		filepath = paths.normalize_path(filepath)
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, ns[tool], 0, -1)
		end
	end
end

return M
