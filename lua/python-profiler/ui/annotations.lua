local highlights = require("python-profiler.ui.highlights")
local paths = require("python-profiler.utils.paths")

local M = {}

local function make_bar(ratio, width)
	local filled = math.floor(ratio * width)
	return string.rep("█", filled) .. string.rep("░", width - filled)
end

function M.annotate_lines(filepath, tool, profiles, total_time, ns)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local lines = profiles[tool][filepath]
	if not lines then
		return
	end

	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, ns[tool], 0, -1)

	for line, t in pairs(lines) do
		local ratio = t.time / total_time[tool]
		local highlight_group = highlights.get_highlight_group(ratio)
		vim.api.nvim_buf_set_extmark(bufnr, ns[tool], line - 1, 0, {
			virt_text = {
				{ make_bar(ratio, 10) .. " ", highlight_group },
				{ string.format("%.3fs (%.1f%%) -- %d calls", t.time, ratio * 100, t.count), highlight_group },
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
