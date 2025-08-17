local highlights = require("python-profiler.ui.highlights")
local paths = require("python-profiler.utils.paths")

local M = {}

local function make_bar(ratio, width, tool)
	local filled = math.floor(ratio * width)
	if tool == "kernprof" then
		return string.rep("█", filled) .. string.rep("░", width - filled)
	else
		return string.rep("▉", filled) .. string.rep("▊", width - filled)
	end
end

function M.annotate_kernprof(filepath, profiles, total_time, ns)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local file_data = profiles.kernprof[filepath]
	if not file_data or not file_data.lines then
		return
	end

	local lines = file_data.lines
	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, ns.kernprof, 0, -1)

	if file_data.functions then
		for _, func in ipairs(file_data.functions) do
			local func_ratio = func.total_time / total_time.kernprof
			local highlight_group = highlights.get_highlight_group(func_ratio)
			vim.api.nvim_buf_set_extmark(bufnr, ns.kernprof, func.start_line - 1, 0, {
				virt_text = {
					{ make_bar(func_ratio, 15, "kernprof") .. " ", highlight_group },
					{
						string.format(
							"[line_profiler] %s: %.3fs (%.1f%% total)",
							func.name,
							func.total_time,
							func_ratio * 100
						),
						highlight_group,
					},
				},
				virt_text_pos = "eol",
			})
		end
	end

	for line, t in pairs(lines) do
		local bar_ratio = t.percent_in_function / 100
		local total_ratio = t.time / total_time.kernprof
		local highlight_group = highlights.get_highlight_group(bar_ratio)

		local function_info = t.function_name and (" [" .. t.function_name .. "]") or ""
		local percent_func = string.format("%.1f%% func", t.percent_in_function)
		local percent_total = string.format("%.1f%% total", total_ratio * 100)
		local per_hit_info = string.format("%.3fs/hit", t.time_per_hit)

		vim.api.nvim_buf_set_extmark(bufnr, ns.kernprof, line - 1, 0, {
			virt_text = {
				{ make_bar(bar_ratio, 10, "kernprof") .. " ", highlight_group },
				{
					string.format(
						"%.3fs %s (%s, %s) -- %d calls [line_profiler]%s",
						t.time,
						per_hit_info,
						percent_func,
						percent_total,
						t.count,
						function_info
					),
					highlight_group,
				},
			},
			virt_text_pos = "eol",
		})
	end
end

function M.annotate_pyinstrument(filepath, profiles, total_time, ns)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local file_data = profiles.pyinstrument[filepath]
	if not file_data or not file_data.functions then
		return
	end

	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, ns.pyinstrument, 0, -1)

	for _, func in ipairs(file_data.functions) do
		local func_ratio = func.total_time / total_time.pyinstrument
		local self_ratio = func.self_time / total_time.pyinstrument
		local highlight_group = highlights.get_highlight_group(func_ratio)

		vim.api.nvim_buf_set_extmark(bufnr, ns.pyinstrument, func.start_line - 1, 0, {
			virt_text = {
				{ make_bar(func_ratio, 15, "pyinstrument") .. " ", highlight_group },
				{
					string.format(
						"[pyinstrument] %s: %.3fs total, %.3fs self (%.1f%% total)",
						func.name,
						func.total_time,
						func.self_time,
						func_ratio * 100
					),
					highlight_group,
				},
			},
			virt_text_pos = "eol",
		})
	end
end

function M.annotate_lines(filepath, tool, profiles, total_time, ns)
	if tool == "kernprof" then
		M.annotate_kernprof(filepath, profiles, total_time, ns)
	elseif tool == "pyinstrument" then
		M.annotate_pyinstrument(filepath, profiles, total_time, ns)
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
