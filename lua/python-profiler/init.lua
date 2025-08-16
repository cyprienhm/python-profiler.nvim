local profiler = require("python-profiler.profiler")

local M = {}

function M.setup()
	profiler.create_gradient_highlights()
	vim.api.nvim_create_user_command("PythonProfileStart", function()
		profiler.profile_with_picker()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileCallStackStart", function()
		profiler.annotate_on_open = true
		profiler.profile_file()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileLinesStart", function()
		profiler.annotate_on_open = true
		profiler.line_profile_file()
	end, {})

	vim.api.nvim_create_user_command("PythonProfileAnnotate", function()
		profiler.annotate_on_open = true
		profiler.annotate_all_open_buffers("pyinstrument")
		profiler.annotate_all_open_buffers("kernprof")
	end, {})

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		pattern = "*.py",
		callback = function()
			if profiler.annotate_on_open then
				vim.schedule(function()
					profiler.annotate_lines(vim.api.nvim_buf_get_name(0), "pyinstrument")
					profiler.annotate_lines(vim.api.nvim_buf_get_name(0), "kernprof")
				end)
			end
		end,
	})

	vim.api.nvim_create_user_command("PythonProfileClear", function()
		profiler.annotate_on_open = false
		profiler.clear_annotations("pyinstrument")
		profiler.clear_annotations("kernprof")
		vim.notify("python-profiler: cleared annotations")
	end, {})
end

return M
