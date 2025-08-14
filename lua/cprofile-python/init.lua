local profiler = require("cprofile-python.profiler")

local M = {}

function M.setup()
	vim.api.nvim_create_user_command("CProfileStart", function()
		profiler.profile_file()
	end, {})
	vim.api.nvim_create_user_command("CProfileAnnotate", function()
		profiler.profile_file()
	end, {})
end

return M
