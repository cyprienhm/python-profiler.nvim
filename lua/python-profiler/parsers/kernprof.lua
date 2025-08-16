local M = {}

local function normalize_path(path)
	return vim.fn.fnamemodify(path, ":p")
end

function M.parse_output(output)
	local profiles = {}
	local total_time = 0
	local current_file = nil

	for line in output:gmatch("[^\r\n]+") do
		local file_match = line:match("^File:%s+(.+)")
		if file_match then
			current_file = normalize_path(file_match)
			profiles[current_file] = {}
		elseif current_file then
			local line_no, hits, time_us = line:match("^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+[%d%.]+%s+[%d%.]+")
			if line_no then
				local line_num = tonumber(line_no)
				local t = tonumber(time_us) / 1e6
				profiles[current_file][line_num] = {
					time = t,
					count = tonumber(hits),
				}
				total_time = total_time + t
			end
		end
	end

	return {
		profiles = profiles,
		total_time = total_time,
	}
end

return M

