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
	local handle =
		io.popen("find . -name '*.py' -not -path '*/.*' -not -path '*/__pycache__/*' | tr '\n' ',' | sed 's/,$//'")
	if handle == nil then
		return ""
	end
	local result = handle:read("*a"):gsub("%s+$", "")
	handle:close()
	return result
end

return M

