local M = {}

local function normalize_path(path)
	return vim.fn.fnamemodify(path, ":p")
end

function M.parse_json_output(json_path)
	local lines = vim.fn.readfile(json_path, "b")
	local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	if not ok or not data then
		return nil, "Failed to parse profiling JSON"
	end

	local profiles = {}
	local total_time = data.root_frame.time

	local function walk(frame)
		if frame.is_application_code then
			local file = normalize_path(frame.file_path)
			profiles[file] = profiles[file] or {}
			local t = profiles[file]
			if not t[frame.line_no] then
				t[frame.line_no] = { time = 0, count = 0 }
			end
			t[frame.line_no].time = t[frame.line_no].time + frame.time
			t[frame.line_no].count = t[frame.line_no].count + 1
		end
		for _, child in ipairs(frame.children or {}) do
			walk(child)
		end
	end

	walk(data.root_frame)

	return {
		profiles = profiles,
		total_time = total_time,
	}
end

return M

