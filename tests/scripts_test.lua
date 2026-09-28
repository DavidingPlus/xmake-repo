local luaunit = require("luaunit")

local path_separator = package.config:sub(1, 1)

local function join_path(...)
    local parts = {}
    local count = select("#", ...)

    for index = 1, count do
        local part = select(index, ...)

        if index > 1 then
            part = part:gsub("^[/\\\\]+", "")
        end

        if index < count then
            part = part:gsub("[/\\\\]+$", "")
        end

        table.insert(parts, part)
    end

    return table.concat(parts, path_separator)
end

local function file_exists(filename)
    local file = io.open(filename, "rb")

    if not file then
        return false
    end

    file:close()
    return true
end

local function read_file(filename)
    local file = assert(io.open(filename, "rb"))
    local content = file:read("*a")
    file:close()
    return content:gsub("\r\n", "\n")
end

local function assert_contains(content, expected)
    luaunit.assertTrue(
        content:find(expected, 1, true) ~= nil,
        "expected to find " .. expected
    )
end

local function command_succeeded(command)
    local result, reason, code = os.execute(command)

    -- Lua 5.1 返回数字；Lua 5.2+ 通常返回 true, "exit", 0。
    if type(result) == "number" then
        return result == 0
    end

    return result == true and (code == nil or code == 0)
end

local function with_stdin_file(input, command, cleanup_files)
    local inputs = type(input) == "table" and input or {input}
    -- 用文件提供多次交互回答，避免 Windows cmd 对 echo 管道的解析差异。
    local input_file = join_path(
        PROJECT_DIR,
        "tests",
        "luaunit_input_" .. os.time() .. "_" .. math.random(100000, 999999) .. ".txt"
    )
    local file = assert(io.open(input_file, "wb"))
    for _, line in ipairs(inputs) do
        file:write(line, "\n")
    end
    file:close()
    table.insert(cleanup_files, input_file)

    return command .. ' < "' .. input_file .. '"'
end

local function quote_argument(value)
    if path_separator == "\\" then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function remove_directory(directory)
    local command

    if path_separator == "\\" then
        command = 'rmdir /s /q "' .. directory .. '" >nul 2>&1'
    else
        command = 'rm -rf -- "' .. directory .. '" >/dev/null 2>&1'
    end

    os.execute(command)
end

local function remove_file(filename)
    local command

    if path_separator == "\\" then
        command = 'del /q "' .. filename .. '" >nul 2>&1'
    else
        command = 'rm -f -- "' .. filename .. '" >/dev/null 2>&1'
    end

    os.execute(command)
end

local function new_package_name()
    return "luaunit-test-" .. os.time() .. "-" .. math.random(100000, 999999)
end

local function package_directory(package_name)
    return join_path(
        PROJECT_DIR,
        "packages",
        package_name:sub(1, 1),
        package_name
    )
end

local template = read_file(join_path(PROJECT_DIR, "scripts", "template.lua"))

TestScripts = {}

function TestScripts:setUp()
    self.generated_package_dirs = {}
    self.generated_input_files = {}
end

function TestScripts:tearDown()
    for _, filename in ipairs(self.generated_input_files) do
        remove_file(filename)
    end
    for _, directory in ipairs(self.generated_package_dirs) do
        remove_directory(directory)
    end
end

function TestScripts:testProjectContainsExpectedTestEntrypoints()
    local xmake = read_file(join_path(PROJECT_DIR, "xmake.lua"))

    luaunit.assertTrue(file_exists(join_path(PROJECT_DIR, "tests", "luaunit", "luaunit.lua")))
    assert_contains(xmake, 'task("create-package")')
    assert_contains(xmake, 'task("luaunit")')
end

function TestScripts:testPackageTemplateContainsEveryPlaceholder()
    assert_contains(template, "{{PACKAGE_NAME}}")
    assert_contains(template, "{{PACKAGE_DESCRIPTION}}")
    assert_contains(template, "{{GITHUB_OWNER}}")
    assert_contains(template, "{{PACKAGE_DEPS}}")
    assert_contains(template, "{{PACKAGE_PLATFORM_DEPS}}")
    assert_contains(template, "{{MACRO_PREFIX}}")
end

function TestScripts:testCreatePackageWithDependencies()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local command = with_stdin_file(
        {"", "fmt, spdlog", "windows-lib", "linux-lib"},
        "xmake create-package " .. package_name,
        self.generated_input_files
    )
    luaunit.assertTrue(command_succeeded(command), "create-package command failed")

    local package_file = join_path(package_dir, "xmake.lua")
    local gitkeep_file = join_path(package_dir, "versions", ".gitkeep")

    luaunit.assertTrue(file_exists(package_file))
    luaunit.assertTrue(file_exists(gitkeep_file))
    luaunit.assertEquals(read_file(gitkeep_file), "")

    local generated = read_file(package_file)
    assert_contains(generated, 'package("' .. package_name .. '")')
    assert_contains(generated, 'set_description("The ' .. package_name .. ' package")')
    assert_contains(generated, 'add_deps("fmt", "spdlog")')
    assert_contains(generated, 'if is_plat("windows") then\n        add_deps("windows-lib")\n    end')
    assert_contains(generated, 'if is_plat("linux") then\n        add_deps("linux-lib")\n    end')
    assert_contains(generated, "on_load(function(package)")
    luaunit.assertNil(generated:find('package:add("deps"', 1, true))
    local on_load_position = generated:find("on_load(function(package)", 1, true)
    luaunit.assertTrue(
        generated:find('add_deps("fmt", "spdlog")', 1, true) < on_load_position
    )
    luaunit.assertTrue(
        generated:find('add_deps("windows-lib")', 1, true) < on_load_position
    )
    assert_contains(generated, "github.com/DavidingPlus/" .. package_name)
    assert_contains(generated, package_name .. "-v$(version)-")
    luaunit.assertNil(generated:find("{{", 1, true))
end

function TestScripts:testCreatePackageWithPackageMetadataJsonArgument()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local macro_prefix = "DLOG"
    local metadata = '{"package_name":"' .. package_name .. '","macro_prefix":"' .. macro_prefix .. '","dependencies":{"common":["fmt"],"windows":["windows-lib"],"linux":["linux-lib"]}}'
    local command = "xmake create-package " .. package_name .. " " .. quote_argument(metadata)
    luaunit.assertTrue(command_succeeded(command), "create-package JSON argument failed")

    local generated = read_file(join_path(package_dir, "xmake.lua"))
    assert_contains(generated, 'add_deps("fmt")')
    assert_contains(generated, 'package:add("defines", "' .. macro_prefix .. '_BUILD_SHARED")')
    luaunit.assertNil(generated:find("{{MACRO_PREFIX}}", 1, true))
    assert_contains(generated, 'if is_plat("windows") then\n        add_deps("windows-lib")\n    end')
    assert_contains(generated, 'if is_plat("linux") then\n        add_deps("linux-lib")\n    end')
end

function TestScripts:testCreatePackageRejectsMismatchedMetadataPackageName()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local metadata = '{"package_name":"different-package","macro_prefix":"DLOG","dependencies":{"common":[],"windows":[],"linux":[]}}'
    local command = "xmake create-package " .. package_name .. " " .. quote_argument(metadata)
    luaunit.assertFalse(
        command_succeeded(command),
        "create-package accepted metadata for a different package"
    )
    luaunit.assertFalse(file_exists(join_path(package_dir, "xmake.lua")))
end

function TestScripts:testCreatePackageRejectsInvalidMetadataMacroPrefix()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local metadata = '{"package_name":"' .. package_name .. '","macro_prefix":"dlog","dependencies":{"common":[],"windows":[],"linux":[]}}'
    local command = "xmake create-package " .. package_name .. " " .. quote_argument(metadata)
    luaunit.assertFalse(
        command_succeeded(command),
        "create-package accepted a lowercase macro prefix"
    )
    luaunit.assertFalse(file_exists(join_path(package_dir, "xmake.lua")))
end

function TestScripts:testCreatePackageRejectsInvalidPackageMetadataJson()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local metadata = '{"package_name":"' .. package_name .. '","macro_prefix":"' .. package_name:upper():gsub("%-", "_") .. '","dependencies":{"common":"fmt"}}'
    local command = "xmake create-package " .. package_name .. " " .. quote_argument(metadata)
    luaunit.assertFalse(
        command_succeeded(command),
        "create-package accepted a dependency group that was not an array"
    )
    luaunit.assertFalse(file_exists(join_path(package_dir, "xmake.lua")))
end

function TestScripts:testCreatePackageWithoutDependencies()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local command = with_stdin_file(
        {"", "", "", ""},
        "xmake create-package " .. package_name,
        self.generated_input_files
    )
    luaunit.assertTrue(command_succeeded(command), "create-package command failed")

    local generated = read_file(join_path(package_dir, "xmake.lua"))

    -- 模板中的示例注释可以保留，但不应生成真正的 add_deps 调用。
    luaunit.assertNil(generated:find("\n    add_deps(", 1, true))
    luaunit.assertNil(generated:find('\n    if is_plat("windows") then', 1, true))
    luaunit.assertNil(generated:find('\n    if is_plat("linux") then', 1, true))
end

function TestScripts:testCreatePackageUsesFirstCharacterAsDirectory()
    local package_name = "zluaunit-test-" .. os.time() .. "-" .. math.random(100000, 999999)
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    luaunit.assertTrue(
        command_succeeded(with_stdin_file(
            {"", "fmt", "", ""},
            "xmake create-package " .. package_name,
            self.generated_input_files
        )),
        "create-package command failed"
    )
    luaunit.assertTrue(file_exists(join_path(package_dir, "xmake.lua")))
end

function TestScripts:testCreatePackageRejectsInvalidPackageNames()
    local invalid_names = {
        "UpperCase",
        "-foo",
        "_foo",
        ".foo",
        "foo/bar",
        "foo@bar",
        "foo bar"
    }

    for _, package_name in ipairs(invalid_names) do
        local command = "xmake create-package " .. package_name
        luaunit.assertFalse(
            command_succeeded(command),
            "invalid package name was accepted: " .. package_name
        )
    end
end

function TestScripts:testCreatePackageRejectsMissingPackageName()
    luaunit.assertFalse(command_succeeded("xmake create-package"))
end

function TestScripts:testCreatePackageRejectsEmptyDependencyEntries()
    local package_name = new_package_name()

    luaunit.assertFalse(
        command_succeeded(
            with_stdin_file(
                {"", "fmt, ,spdlog"},
                "xmake create-package " .. package_name,
                self.generated_input_files
            )
        )
    )
    luaunit.assertFalse(file_exists(join_path(package_directory(package_name), "xmake.lua")))
end

function TestScripts:testCreatePackageRejectsBackslashInDependencyName()
    local package_name = new_package_name()

    luaunit.assertFalse(
        command_succeeded(
            with_stdin_file(
                {"", "fmt, bad\\dependency"},
                "xmake create-package " .. package_name,
                self.generated_input_files
            )
        )
    )
    luaunit.assertFalse(file_exists(join_path(package_directory(package_name), "xmake.lua")))
end

function TestScripts:testCreatePackageRefusesToOverwriteExistingPackage()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    luaunit.assertTrue(
        command_succeeded(with_stdin_file(
            {"", "fmt", "", ""},
            "xmake create-package " .. package_name,
            self.generated_input_files
        )),
        "initial package generation failed"
    )

    luaunit.assertFalse(
        command_succeeded(with_stdin_file(
            {"", "fmt", "", ""},
            "xmake create-package " .. package_name,
            self.generated_input_files
        )),
        "existing package was overwritten"
    )

    luaunit.assertTrue(file_exists(join_path(package_dir, "xmake.lua")))
end
