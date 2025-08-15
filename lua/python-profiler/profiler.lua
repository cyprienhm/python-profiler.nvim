local M = {}
M.profiles = {}
M.ns = vim.api.nvim_create_namespace("profiler")
M.annotate_on_open = false

local function normalize_path(path)
	return vim.fn.fnamemodify(path, ":p") -- absolute path
end

function M.profile_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	filepath = normalize_path(filepath)
	vim.notify("python-profiler: profiling " .. filepath .. " ...")

	vim.system({ "pyinstrument", "-r", "json", "-o", "/tmp/python-profile.json", filepath }, {
		stdout_buffered = true,
		stderr_buffered = true,
	}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				vim.notify("Profiling failed: " .. (res.stderr or ""))
				return
			end

			local lines = vim.fn.readfile("/tmp/python-profile.json", "b")
			local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
			if not ok or not data then
				vim.notify("Failed to parse profiling JSON")
				return
			end

			local function walk(frame)
				if frame.is_application_code then
					local file = frame.file_path
					file = normalize_path(file)
					M.profiles[file] = M.profiles[file] or {}
					local t = M.profiles[file]
					t[frame.line_no] = (t[frame.line_no] or 0) + frame.time
				end
				for _, child in ipairs(frame.children or {}) do
					walk(child)
				end
			end
			walk(data.root_frame)

			M.annotate_all_open_buffers()
		end)
	end)
end

function M.annotate_all_open_buffers()
	for filepath, _ in pairs(M.profiles) do
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			M.annotate_lines(filepath)
		end
	end
end

function M.annotate_lines(filepath)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	filepath = normalize_path(filepath)
	local lines = M.profiles[filepath]
	if not lines then
		return
	end

	local bufnr = vim.fn.bufnr(filepath, true)
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

	for line, t in pairs(lines) do
		vim.api.nvim_buf_set_extmark(bufnr, M.ns, line - 1, 0, {
			virt_text = { { string.format("%.3fs", t), "ErrorMsg" } },
			virt_text_pos = "eol",
		})
	end
end

function M.clear_annotations()
	for filepath, _ in pairs(M.profiles) do
		filepath = normalize_path(filepath)
		local bufnr = vim.fn.bufnr(filepath, true)
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
		end
	end
end

return M
