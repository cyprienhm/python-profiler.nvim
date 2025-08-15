local profiler = require("python-profiler.profiler")

local M = {}

function M.setup()
	vim.api.nvim_create_user_command("PythonProfileStart", function()
		profiler.profile_file()
	end, {})
	vim.api.nvim_create_user_command("PythonProfileAnnotate", function()
		profiler.is_annotating = true
		profiler.annotate_lines()
	end, {})
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		pattern = "*.py",
		callback = function()
			if profiler.is_annotating then
				profiler.annotate_lines()
			end
		end,
	})
	vim.api.nvim_create_user_command("PythonProfileClear", function()
		profiler.is_annotating = false
		profiler.clear_annotations()
		vim.notify("python-profiler: cleared annotations")
	end, {})
end

return M
