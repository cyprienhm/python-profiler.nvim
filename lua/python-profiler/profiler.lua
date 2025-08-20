local pyinstrument_parser = require("python-profiler.parsers.pyinstrument")
local kernprof_parser = require("python-profiler.parsers.kernprof")
local files = require("python-profiler.utils.files")
local paths = require("python-profiler.utils.paths")
local annotations = require("python-profiler.ui.annotations")
local state = require("python-profiler.state")
local spinner = require("python-profiler.utils.spinner")
local notifications = require("python-profiler.utils.notifications")

local M = {}

local function check_command_exists(cmd)
	return vim.fn.executable(cmd) == 1
end

function M.profile_file(args)
	if not check_command_exists("pyinstrument") then
		notifications.show(
			"python-profiler: pyinstrument not found. Install pyinstrument: `pip install pyinstrument`",
			vim.log.levels.ERROR
		)
		return
	end

	local filepath = vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local cmd = { "pyinstrument", "-r", "json", "-o", paths.get_temp_json_path(), filepath }

	if args and args ~= "" then
		for arg in args:gmatch("%S+") do
			table.insert(cmd, arg)
		end
	end

	local spinner_id = spinner.start("Profiling with pyinstrument...")

	vim.system(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				spinner.stop(spinner_id, "python-profiler: profiling failed: " .. (res.stderr or ""))
				return
			end

			local result, err = pyinstrument_parser.parse_json_output(paths.get_temp_json_path())
			if not result then
				spinner.stop(spinner_id, "python-profiler: " .. err)
				return
			end

			state.profiles.pyinstrument = result.profiles
			state.total_time.pyinstrument = result.total_time

			annotations.annotate_all_open_buffers("pyinstrument", state.profiles, state.total_time, state.ns)
			spinner.stop(spinner_id, "python-profiler: pyinstrument profiling complete")
		end)
	end)
end

function M.line_profile_file(args)
	if not check_command_exists("kernprof") then
		notifications.show(
			"python-profiler: kernprof not found. Install line_profiler: `pip install line_profiler`",
			vim.log.levels.ERROR
		)
		return
	end

	local filepath = vim.api.nvim_buf_get_name(0)
	filepath = paths.normalize_path(filepath)
	local modules = files.discover_python_modules()
	modules = modules .. "," .. filepath

	if modules == "" then
		notifications.show("python-profiler: no Python modules found to profile", vim.log.levels.WARN)
		return
	end

	local lprof_file = paths.get_temp_lprof_path(filepath)
	local cmd = { "kernprof", "-l", "-o", lprof_file, "-p", modules, filepath }

	if args and args ~= "" then
		for arg in args:gmatch("%S+") do
			table.insert(cmd, arg)
		end
	end

	local spinner_id = spinner.start("Profiling with line_profiler...")

	vim.system(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				spinner.stop(spinner_id, "python-profiler: line profiling failed: " .. (res.stderr or ""))
				return
			end

			vim.system({ "python", "-m", "line_profiler", "-zrmt", lprof_file }, {
				stdout_buffered = true,
				stderr_buffered = true,
			}, function(res2)
				vim.schedule(function()
					if res2.code ~= 0 then
						spinner.stop(spinner_id, "python-profiler: failed to read lprof file: " .. (res2.stderr or ""))
						return
					end

					local result = kernprof_parser.parse_output(res2.stdout)
					state.profiles.kernprof = result.profiles
					state.total_time.kernprof = result.total_time
					annotations.annotate_all_open_buffers("kernprof", state.profiles, state.total_time, state.ns)
					spinner.stop(spinner_id, "python-profiler: line_profiler profiling complete")
				end)
			end)
		end)
	end)
end

function M.profile_with_picker()
	local options = {
		"pyinstrument: Call stack profile current file",
		"pyinstrument: Call stack profile with arguments",
		"line_profiler: Line profile current file",
		"line_profiler: Line profile with arguments",
	}

	vim.ui.select(options, {
		prompt = "Select profiling mode:",
	}, function(choice, idx)
		if not idx then
			return
		end

		if idx == 1 then
			state.annotate_on_open = true
			M.profile_file()
		elseif idx == 2 then
			vim.ui.input({
				prompt = "Arguments: ",
			}, function(args)
				if args then
					state.annotate_on_open = true
					M.profile_file(args)
				end
			end)
		elseif idx == 3 then
			state.annotate_on_open = true
			M.line_profile_file()
		elseif idx == 4 then
			vim.ui.input({
				prompt = "Arguments: ",
			}, function(args)
				if args then
					state.annotate_on_open = true
					M.line_profile_file(args)
				end
			end)
		end
	end)
end

return M
