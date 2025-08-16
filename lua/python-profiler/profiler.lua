local pyinstrument_parser = require("python-profiler.parsers.pyinstrument")
local kernprof_parser = require("python-profiler.parsers.kernprof")
local files = require("python-profiler.utils.files")
local paths = require("python-profiler.utils.paths")

local M = {}
M.profiles = { pyinstrument = {}, kernprof = {} }
M.total_time = { pyinstrument = 0, kernprof = 0 }
M.ns = {
	pyinstrument = vim.api.nvim_create_namespace("profiler_pyinstrument"),
	kernprof = vim.api.nvim_create_namespace("profiler_kernprof"),
}
M.annotate_on_open = false

function M.create_gradient_highlights()
	for i = 0, 9 do
		local ratio = i / 9
		local r = math.floor(ratio * 255)
		local g = math.floor((1 - ratio) * 128)
		local b = math.floor((1 - ratio) * 255)

		local color = string.format("#%02x%02x%02x", r, g, b)
		vim.api.nvim_set_hl(0, "ProfilerHeat" .. i, { fg = color })
	end
end

local function get_highlight_group(ratio)
	local step = math.min(9, math.floor(ratio * 10))
	return "ProfilerHeat" .. step
end

local function make_bar(ratio, width)
	local filled = math.floor(ratio * width)
	return string.rep("█", filled) .. string.rep("░", width - filled)
end

function M.profile_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	vim.notify("python-profiler: profiling " .. filepath .. " ...")

	vim.system({ "pyinstrument", "-r", "json", "-o", paths.get_temp_json_path(), filepath }, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				vim.notify("python-profiler: profiling failed: " .. (res.stderr or ""))
				return
			end

			local result, err = pyinstrument_parser.parse_json_output(paths.get_temp_json_path())
			if not result then
				vim.notify("python-profiler: " .. err)
				return
			end

			M.profiles.pyinstrument = result.profiles
			M.total_time.pyinstrument = result.total_time

			M.annotate_all_open_buffers("pyinstrument")
		end)
	end)
end

function M.annotate_all_open_buffers(tool)
	for filepath, _ in pairs(M.profiles[tool]) do
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			M.annotate_lines(filepath, tool)
		end
	end
end

function M.annotate_lines(filepath, tool)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local lines = M.profiles[tool][filepath]
	if not lines then
		return
	end

	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns[tool], 0, -1)

	for line, t in pairs(lines) do
		local ratio = t.time / M.total_time[tool]
		local highlight_group = get_highlight_group(ratio)
		vim.api.nvim_buf_set_extmark(bufnr, M.ns[tool], line - 1, 0, {
			virt_text = {
				{ make_bar(ratio, 10) .. " ", highlight_group },
				{ string.format("%.3fs (%.1f%%) -- %d calls", t.time, ratio * 100, t.count), highlight_group },
			},
			virt_text_pos = "eol",
		})
	end
end

function M.clear_annotations(tool)
	for filepath, _ in pairs(M.profiles[tool]) do
		filepath = paths.normalize_path(filepath)
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, M.ns[tool], 0, -1)
		end
	end
end

function M.line_profile_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local modules = files.discover_python_files()

	if modules == "" then
		vim.notify("python-profiler: no Python modules found to profile")
		return
	end

	local lprof_file = paths.get_lprof_path(filepath)
	vim.notify("python-profiler: line profiling " .. filepath .. " with modules: " .. modules)

	vim.system({ "kernprof", "-l", "-p", modules, filepath }, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				vim.notify("python-profiler: line profiling failed: " .. (res.stderr or ""))
				return
			end

			vim.system({ "python", "-m", "line_profiler", "-zrmt", lprof_file }, {
				stdout_buffered = true,
				stderr_buffered = true,
			}, function(res2)
				vim.schedule(function()
					if res2.code ~= 0 then
						vim.notify("python-profiler: failed to read lprof file: " .. (res2.stderr or ""))
						return
					end

					local result = kernprof_parser.parse_output(res2.stdout)
					M.profiles.kernprof = result.profiles
					M.total_time.kernprof = result.total_time
					M.annotate_all_open_buffers("kernprof")
				end)
			end)
		end)
	end)
end

return M
