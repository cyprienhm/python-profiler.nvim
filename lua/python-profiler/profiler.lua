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

	local result = vim.system({
		"python",
		"-c",
		[[
import pstats, json
stats = pstats.Stats("out.prof")
data = []
for func, stat in stats.stats.items():
    filename, line, name = func
    cc, nc, tt, ct, callers = stat
    data.append({"func": name, "file": filename, "time": tt, "cum_time": ct})
print(json.dumps(data))
  ]],
	}):wait()

	vim.notify("Read out.prof")
	local decoded = vim.json.decode(result.stdout)
	print(vim.inspect(decoded))
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
