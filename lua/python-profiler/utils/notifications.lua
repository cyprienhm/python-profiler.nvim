local M = {}
local has_notify, notify = pcall(require, "notify")

function M.show(msg, level, opts)
	if has_notify then
		return notify(msg or "", level or vim.log.levels.INFO, opts or {})
	else
		vim.api.nvim_echo({ { msg or "" } }, false, {})
		return nil
	end
end

return M
