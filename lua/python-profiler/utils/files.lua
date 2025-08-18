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
	local root = vim.fn.getcwd()
	local files = vim.fs.find(function(name, path)
		return name:match("%.py$") and not path:match("/__pycache__/") and not path:match("/%.")
	end, { type = "file", limit = math.huge, path = root })

	return table.concat(files, ",")
end

return M
