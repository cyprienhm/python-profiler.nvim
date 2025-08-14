local profiler = require("python-profiler.profiler")

local M = {}

function M.setup()
	vim.api.nvim_create_user_command("PythonProfileStart", function()
		profiler.profile_file()
	end, {})
	vim.api.nvim_create_user_command("PythonProfileAnnotate", function()
		profiler.annotate_lines()
	end, {})
end

return M
