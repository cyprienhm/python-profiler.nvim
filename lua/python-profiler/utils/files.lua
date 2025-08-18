local M = {}

function M.read_json_file(filepath)
	local lines = vim.fn.readfile(filepath, "b")
	local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	if not ok or not data then
		return nil, "Failed to parse JSON file: " .. filepath
	end
	return data
end

function M.discover_python_files()
	local cmd = {
		"fd",
		"-e",
		"py",
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
		"-E",
		"node_modules",
		"-E",
		"*.egg-info",
		"-0",
	}
	local result = vim.system(cmd, { text = true }):wait()
	if result.code ~= 0 then
		return ""
	end
	return result.stdout:gsub("%z", ","):gsub(",$", "")
end

return M
