local M = {}
local notifications = require("python-profiler.utils.notifications")

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinners, counter = {}, 0

function M.start(message)
	counter = counter + 1
	local id = "spinner_" .. counter
	local timer = vim.uv.new_timer()
	spinners[id] = { timer = timer, i = 1, notify_id = nil, message = message }

	timer:start(
		0,
		80,
		vim.schedule_wrap(function()
			local s = spinners[id]
			if not s then
				return
			end
			local frame = frames[s.i]
			s.notify_id = notifications.show(frame .. " " .. s.message, vim.log.levels.INFO, {
				replace = s.notify_id,
				timeout = 0,
				hide_from_history = true,
			})
			s.i = (s.i % #frames) + 1
		end)
	)

	return id
end

function M.stop(id, final_message)
	local s = spinners[id]
	if not s then
		return
	end
	s.timer:stop()
	s.timer:close()
	spinners[id] = nil

	if final_message then
		notifications.show(final_message, vim.log.levels.INFO, { replace = s.notify_id, timeout = 2000 })
	else
		notifications.show("", vim.log.levels.INFO, { replace = s.notify_id, hide_from_history = true, timeout = 1 })
	end
end

function M.cleanup_all()
	for _, s in pairs(spinners) do
		s.timer:stop()
		s.timer:close()
	end
	spinners = {}
end

return M
