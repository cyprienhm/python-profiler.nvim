local highlights = require("python-profiler.ui.highlights")
local paths = require("python-profiler.utils.paths")

local M = {}

local bar_cache = {}
local function make_bar(ratio, width, style)
	local key = string.format("%d_%d_%s", math.floor(ratio * 100), width, style)
	if bar_cache[key] then
		return bar_cache[key]
	end

	local filled = math.floor(ratio * width)
	local chars = style == "kernprof" and { filled = "█", empty = "░" } or { filled = "▉", empty = "▊" }

	local bar = string.rep(chars.filled, filled) .. string.rep(chars.empty, width - filled)
	bar_cache[key] = bar
	return bar
end

local function safe_ratio(numerator, denominator, default)
	if not numerator or not denominator or denominator == 0 then
		return default or 0
	end
	return numerator / denominator
end

local function annotate_kernprof_function(bufnr, func, total_time, ns)
	local ratio = safe_ratio(func.total_time, total_time)
	local highlight = highlights.get_highlight_group(ratio)

	vim.api.nvim_buf_set_extmark(bufnr, ns, func.start_line - 1, 0, {
		virt_text = {
			{ make_bar(ratio, 15, "kernprof") .. " ", highlight },
			{
				string.format("[line_profiler] %s: %.3fs (%.1f%% total)", func.name, func.total_time, ratio * 100),
				highlight,
			},
		},
		virt_text_pos = "eol",
		priority = 100,
	})
end

local function annotate_kernprof_line(bufnr, line_num, data, total_time, ns)
	local bar_ratio = safe_ratio(data.percent_in_function, 100)
	local total_ratio = safe_ratio(data.time, total_time)
	local highlight = highlights.get_highlight_group(bar_ratio)

	local parts = {
		string.format("%.3fs", data.time),
		string.format("%.3fs/hit", data.time_per_hit or 0),
		string.format("(%.1f%% func, %.1f%% total)", data.percent_in_function or 0, total_ratio * 100),
		string.format("-- %d calls", data.count or 0),
		"[line_profiler]",
	}

	if data.function_name then
		table.insert(parts, string.format(" [%s]", data.function_name))
	end

	vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, 0, {
		virt_text = {
			{ make_bar(bar_ratio, 10, "kernprof") .. " ", highlight },
			{ table.concat(parts, " "), highlight },
		},
		virt_text_pos = "eol",
	})
end

function M.annotate_kernprof(bufnr, file_data, total_time, ns)
	if not file_data then
		return false
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	if file_data.functions then
		for _, func in ipairs(file_data.functions) do
			annotate_kernprof_function(bufnr, func, total_time, ns)
		end
	end

	if file_data.lines then
		for line_num, data in pairs(file_data.lines) do
			annotate_kernprof_line(bufnr, line_num, data, total_time, ns)
		end
	end

	return true
end

function M.annotate_pyinstrument(bufnr, file_data, total_time, ns)
	if not file_data or not file_data.functions then
		return false
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for _, func in ipairs(file_data.functions) do
		local func_ratio = safe_ratio(func.total_time, total_time)
		local highlight = highlights.get_highlight_group(func_ratio)

		vim.api.nvim_buf_set_extmark(bufnr, ns, func.start_line - 1, 0, {
			virt_text = {
				{ make_bar(func_ratio, 15, "pyinstrument") .. " ", highlight },
				{
					string.format(
						"[pyinstrument] %s: %.3fs total, %.3fs self (%.1f%% total)",
						func.name,
						func.total_time or 0,
						func.self_time or 0,
						func_ratio * 100
					),
					highlight,
				},
			},
			virt_text_pos = "eol",
		})
	end

	return true
end

function M.annotate_buffer(filepath, tool, profiles, total_time, ns)
	filepath = paths.normalize_path(filepath)

	local file_data = profiles[tool] and profiles[tool][filepath]
	if not file_data then
		return false
	end

	local bufnr = vim.fn.bufnr(filepath)
	if bufnr == -1 then
		return false
	end

	local tool_total = total_time[tool]
	if not tool_total or tool_total == 0 then
		return false
	end

	if tool == "kernprof" then
		return M.annotate_kernprof(bufnr, file_data, tool_total, ns.kernprof)
	elseif tool == "pyinstrument" then
		return M.annotate_pyinstrument(bufnr, file_data, tool_total, ns.pyinstrument)
	end

	return false
end

function M.annotate_all_open_buffers(tool, profiles, total_time, ns)
	if not profiles[tool] then
		return 0
	end

	local annotated = 0
	local loaded_buffers = {}

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" then
				loaded_buffers[paths.normalize_path(name)] = bufnr
			end
		end
	end

	for filepath, _ in pairs(profiles[tool]) do
		local normalized = paths.normalize_path(filepath)
		local bufnr = loaded_buffers[normalized]

		if bufnr then
			local file_data = profiles[tool][filepath]
			local tool_total = total_time[tool]

			if tool_total and tool_total > 0 then
				local success
				if tool == "kernprof" then
					success = M.annotate_kernprof(bufnr, file_data, tool_total, ns.kernprof)
				elseif tool == "pyinstrument" then
					success = M.annotate_pyinstrument(bufnr, file_data, tool_total, ns.pyinstrument)
				end

				if success then
					annotated = annotated + 1
				end
			end
		end
	end

	return annotated
end

function M.clear_annotations(tool, profiles, ns)
	if not profiles[tool] then
		return 0
	end

	local cleared = 0
	for filepath, _ in pairs(profiles[tool]) do
		local normalized = paths.normalize_path(filepath)
		local bufnr = vim.fn.bufnr(normalized)

		if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, ns[tool], 0, -1)
			cleared = cleared + 1
		end
	end

	return cleared
end

return M
