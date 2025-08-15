local M = {}
M.last_profile = ""

function M.profile_file()
	vim.notify("python-profiler: starting profiling...")
	local filepath = vim.api.nvim_buf_get_name(0)

	vim.system({ "pyinstrument", "-r", "json", "-o", "/tmp/python-profile.json", filepath }, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				vim.notify("Profiling failed: " .. (res.stderr or ""))
				return
			end

			local data = vim.fn.json_decode(vim.fn.readfile("/tmp/python-profile.json", "b"))
			if not data then
				vim.notify("Failed to parse profiling JSON")
				return
			end

			local times = {}
			local function walk(frame)
				if frame.is_application_code then
					local file = frame.file_path:match("[^/]+$")
					times[file] = times[file] or {}
					times[file][frame.line_no] = (times[file][frame.line_no] or 0) + frame.time
				end
				for _, child in ipairs(frame.children or {}) do
					walk(child)
				end
			end
			walk(data.root_frame)

			M.last_profile = times
			vim.notify("python-profiler: profiling done. Run PythonProfileAnnotate.")
		end)
	end)
end

function M.annotate_lines()
	vim.notify("python-profiler: annotating...")
	if not M.last_profile then
		return
	end
	local file = vim.fn.expand("%:t")
	local lines = M.last_profile[file]
	if not lines then
		return
	end
	local ns = vim.api.nvim_create_namespace("profiler")
	local bufnr = vim.api.nvim_get_current_buf()
	for line, t in pairs(lines) do
		vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
			virt_text = { { string.format("%.3fs", t), "ErrorMsg" } },
			virt_text_pos = "eol",
		})
	end
end

return M
