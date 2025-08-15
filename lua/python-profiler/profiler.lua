local M = {}
M.last_profile = ""

PYTHON_CODE = [[
import json
from collections import defaultdict
from pathlib import Path

with open("prof.json") as f:
    data = json.load(f)

times = defaultdict(float)


def walk(frame):
    if frame.get("is_application_code"):
        key = (frame["file_path"], frame["line_no"])
        times[key] += frame["time"]
    for child in frame.get("children", []):
        walk(child)


walk(data["root_frame"])


def to_lua_table(d):
    out = ["return {"]
    files = {}
    for (file, line), t in d.items():
        short = file.split("/")[-1]
        files.setdefault(short, {})[line] = t
    for file, lines in files.items():
        out.append(f'  ["{file}"] = {{')
        for line, t in sorted(lines.items()):
            out.append(f"    [{line}] = {t},")
        out.append("  },")
    out.append("}")
    return "\n".join(out)


print(to_lua_table(times))
  ]]

function M.profile_file()
	vim.notify("python-profiler: starting profiling...")
	local filepath = vim.api.nvim_buf_get_name(0)
	vim.system({ "pyinstrument", "-o", "prof.json", filepath }):wait()
	local output = vim.system({ "python", "-c", PYTHON_CODE }):wait().stdout
	if not output then
		vim.notify("Profiling failed")
		return
	end
	local f, err = load(output)
	if not f then
		vim.notify("Failed to load Lua table: " .. err)
		return
	end
	M.last_profile = f()
	vim.notify("python-profiler: profiling done. Run PythonProfileAnnotate.")
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
