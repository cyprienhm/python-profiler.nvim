local profiler = require("python-profiler.profiler")
local highlights = require("python-profiler.ui.highlights")
local annotations = require("python-profiler.ui.annotations")
local state = require("python-profiler.state")

local M = {}

function M.setup()
	highlights.create_gradient_highlights()
	vim.api.nvim_create_user_command("PythonProfileStart", function()
		profiler.profile_with_picker()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileCallStackStart", function()
		state.annotate_on_open = true
		profiler.profile_file()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileLinesStart", function()
		state.annotate_on_open = true
		profiler.line_profile_file()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileAnnotate", function()
		state.annotate_on_open = true
		annotations.annotate_all_open_buffers("pyinstrument", state.profiles, state.total_time, state.ns)
		annotations.annotate_all_open_buffers("kernprof", state.profiles, state.total_time, state.ns)
	end, {})

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		pattern = "*.py",
		callback = function()
			if state.annotate_on_open then
				vim.schedule(function()
					local filepath = vim.api.nvim_buf_get_name(0)
					annotations.annotate_lines(filepath, "pyinstrument", state.profiles, state.total_time, state.ns)
					annotations.annotate_lines(filepath, "kernprof", state.profiles, state.total_time, state.ns)
				end)
			end
		end,
	})

	vim.api.nvim_create_user_command("PythonProfileClear", function()
		state.annotate_on_open = false
		annotations.clear_annotations("pyinstrument", state.profiles, state.ns)
		annotations.clear_annotations("kernprof", state.profiles, state.ns)
		vim.notify("python-profiler: cleared annotations")
	end, {})
end

return M
