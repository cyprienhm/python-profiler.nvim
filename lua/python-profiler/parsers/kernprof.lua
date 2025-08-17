local M = {}
local paths = require("python-profiler.utils.paths")

function M.parse_output(output)
	local profiles = {}
	local total_time = 0
	local current_file = nil
	local current_function = nil
	local pending_func_time = nil

	for line in output:gmatch("[^\r\n]+") do
		-- Parse function total time: "Total time: 1.25296 s"
		local func_total = line:match("^Total time:%s+([%d%.e%-]+)%s+s")
		if func_total then
			pending_func_time = tonumber(func_total)
			total_time = total_time + pending_func_time
		end

		-- Parse file: "File: /path/to/file.py"
		local file_match = line:match("^File:%s+(.+)")
		if file_match then
			current_file = paths.normalize_path(file_match)
			if not profiles[current_file] then
				profiles[current_file] = {
					functions = {},
					lines = {},
				}
			end
		end

		-- Parse function: "Function: util_func at line 4"
		local func_name, func_line = line:match("^Function:%s+(.+)%s+at%s+line%s+(%d+)")
		if func_name and func_line and current_file then
			current_function = {
				name = func_name,
				start_line = tonumber(func_line),
				total_time = pending_func_time or 0,
				lines = {},
			}
			table.insert(profiles[current_file].functions, current_function)
			pending_func_time = nil
		end

		-- Parse line data: Line #  Hits   Time   Per hit   % Time    Line Contents
		--                      11     1    3.0       3.0      0.0   print("hello")
		if current_file and current_function then
			local line_no, hits, time_us, per_hit, percent_time =
				line:match("^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
			if line_no then
				local line_num = tonumber(line_no)
				local t = tonumber(time_us) / 1e6
				local count = tonumber(hits)
				local time_per_hit = tonumber(per_hit) / 1e6
				local percent_in_function = tonumber(percent_time)

				current_function.lines[line_num] = {
					time = t,
					count = count,
					time_per_hit = time_per_hit,
					percent_in_function = percent_in_function,
				}

				profiles[current_file].lines[line_num] = {
					time = t,
					count = count,
					time_per_hit = time_per_hit,
					percent_in_function = percent_in_function,
					function_name = current_function.name,
				}
			end
		end
	end

	return {
		profiles = profiles,
		total_time = total_time,
	}
end

return M
