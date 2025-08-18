local M = {}

function M.normalize_path(path)
	return vim.fn.fnamemodify(path, ":p")
end

function M.get_temp_json_path()
	return "/tmp/python-profile.json"
end

function M.get_lprof_path(filepath)
	return filepath .. ".lprof"
end

function M.get_temp_lprof_path(filepath)
	local filename = vim.fn.fnamemodify(filepath, ":t")
	return "/tmp/" .. filename .. ".lprof"
end

return M
