local M = {}

function M.profile_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	local res = vim.system({
		"python",
		"-m",
		"cProfile",
		"-o",
		"out.prof",
		filepath,
	})
	vim.notify("Profiling " .. filepath)
	res:wait()
end

function M.annotate_lines()
	local ns = vim.api.nvim_create_namespace("hello_plugin")
	local bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
		virt_text = { { "Hello", "ErrorMsg" } },
		virt_text_pos = "eol",
	})
end

return M
