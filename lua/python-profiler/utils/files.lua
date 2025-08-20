local M = {}

function M.read_json_file(filepath)
	local lines = vim.fn.readfile(filepath, "b")
	local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	if not ok or not data then
		return nil, "Failed to parse JSON file: " .. filepath
	end
	return data
end

function M.discover_python_modules()
	local cmd = {
		"fd",
		"__init__.py",
		"-t",
		"f",
		"-H",
		"-E",
		".git",
		"-E",
		"__pycache__",
		"-E",
		"venv",
		"-E",
		".venv",
		"--exec-batch",
		"dirname",
		"{}",
	}
	local result = vim.system(cmd, { text = true }):wait()
	if result.code ~= 0 then
		return ""
	end

	local modules = {}
	for dir in result.stdout:gmatch("[^\n]+") do
		modules[dir] = true
	end

	return table.concat(vim.tbl_keys(modules), ",")
end

return M
