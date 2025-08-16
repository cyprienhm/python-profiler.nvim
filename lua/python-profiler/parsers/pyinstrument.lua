local M = {}
local files = require("python-profiler.utils.files")
local paths = require("python-profiler.utils.paths")

function M.parse_json_output(json_path)
	local data, err = files.read_json_file(json_path)
	if not data then
		return nil, err
	end

	local profiles = {}
	local total_time = data.root_frame.time

	local function walk(frame)
		if frame.is_application_code then
			local file = paths.normalize_path(frame.file_path)
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
