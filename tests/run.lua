local script_path = arg[0]
local tests_dir = script_path:match("^(.*)[/\\\\][^/\\\\]+$") or "."
local project_dir = tests_dir:match("^(.*)[/\\\\]tests$") or "."
local path_separator = package.config:sub(1, 1)

package.path = tests_dir .. path_separator .. "?.lua;"
    .. tests_dir .. path_separator .. "luaunit" .. path_separator .. "?.lua;"
    .. package.path
PROJECT_DIR = project_dir

local luaunit = require("luaunit")

require("scripts_test")

os.exit(luaunit.LuaUnit:run())
