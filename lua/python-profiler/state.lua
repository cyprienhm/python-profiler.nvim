local M = {}

M.profiles = { pyinstrument = {}, kernprof = {} }
M.total_time = { pyinstrument = 0, kernprof = 0 }
M.ns = {
	pyinstrument = vim.api.nvim_create_namespace("profiler_pyinstrument"),
	kernprof = vim.api.nvim_create_namespace("profiler_kernprof"),
}
M.annotate_on_open = false

function M.clear()
	M.profiles = { pyinstrument = {}, kernprof = {} }
	M.total_time = { pyinstrument = 0, kernprof = 0 }
	M.annotate_on_open = false
end

return M

