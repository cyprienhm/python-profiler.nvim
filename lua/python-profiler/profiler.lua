local M = {}
M.last_profile = ""
M.ns = M.ns or vim.api.nvim_create_namespace("profiler")
M.is_annotating = false

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
			vim.notify("python-profiler: profiling done. Annotating.")
			M.annotate_lines()
		end)
	end)
end

function M.annotate_lines()
	vim.notify("python-profiler: annotating...")
	M.is_annotating = true
	if not M.last_profile then
		return
	end
	local file = vim.fn.expand("%:t")
	local lines = M.last_profile[file]
	if not lines then
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()
	M.clear_annotations()
	for line, t in pairs(lines) do
		vim.api.nvim_buf_set_extmark(bufnr, M.ns, line - 1, 0, {
			virt_text = { { string.format("%.3fs", t), "ErrorMsg" } },
			virt_text_pos = "eol",
		})
	end
end

function M.clear_annotations()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

return M
