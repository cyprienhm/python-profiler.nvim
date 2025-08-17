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
		if not frame.is_application_code then
			for _, child in ipairs(frame.children or {}) do
				walk(child)
			end
			return
		end

		local file = paths.normalize_path(frame.file_path)
		if not profiles[file] then
			profiles[file] = { functions = {} }
		end

		-- exclusive time
		local children_time = 0
		for _, child in ipairs(frame.children or {}) do
			children_time = children_time + child.time
		end
		local self_time = frame.time - children_time

		-- aggregate function
		local existing_func = nil
		for _, func in ipairs(profiles[file].functions) do
			if func.name == frame["function"] and func.start_line == frame.line_no then
				existing_func = func
				break
			end
		end

		if not existing_func then
			existing_func = {
				name = frame["function"],
				start_line = frame.line_no,
				total_time = frame.time,
				self_time = self_time,
			}
			table.insert(profiles[file].functions, existing_func)
		else
			existing_func.total_time = existing_func.total_time + frame.time
			existing_func.self_time = existing_func.self_time + self_time
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
