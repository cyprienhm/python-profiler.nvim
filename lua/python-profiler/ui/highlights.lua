local M = {}

function M.create_gradient_highlights()
	for i = 0, 9 do
		local ratio = i / 9
		local r = math.floor(ratio * 255)
		local g = math.floor((1 - ratio) * 128)
		local b = math.floor((1 - ratio) * 255)

		local color = string.format("#%02x%02x%02x", r, g, b)
		vim.api.nvim_set_hl(0, "ProfilerHeat" .. i, { fg = color })
	end
end

function M.get_highlight_group(ratio)
	local step = math.min(9, math.floor(ratio * 10))
	return "ProfilerHeat" .. step
end

return M
