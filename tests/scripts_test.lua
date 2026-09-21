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
    return content
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

local function pipe_input(input, command)
    local producer

    if path_separator == "\\" then
        producer = input == "" and "echo." or "echo " .. input
    else
        producer = 'printf "%s\\n" "' .. input .. '"'
    end

    return producer .. " | " .. command
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

local function new_package_name()
    return "luaunit_test_" .. os.time() .. "_" .. math.random(100000, 999999)
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
end

function TestScripts:tearDown()
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
end

function TestScripts:testCreatePackageWithDependencies()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local command = pipe_input(
        "fmt, spdlog",
        "xmake create-package " .. package_name
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
    assert_contains(generated, "github.com/DavidingPlus/" .. package_name)
    assert_contains(generated, package_name .. "-v$(version)-")
    luaunit.assertNil(generated:find("{{", 1, true))
end

function TestScripts:testCreatePackageWithoutDependencies()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    local command = pipe_input("", "xmake create-package " .. package_name)
    luaunit.assertTrue(command_succeeded(command), "create-package command failed")

    local generated = read_file(join_path(package_dir, "xmake.lua"))

    -- 模板中的示例注释可以保留，但不应生成真正的 add_deps 调用。
    luaunit.assertNil(generated:find("\n    add_deps(", 1, true))
end

function TestScripts:testCreatePackageUsesFirstCharacterAsDirectory()
    local package_name = "zluaunit-test." .. os.time() .. "_" .. math.random(100000, 999999)
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    luaunit.assertTrue(
        command_succeeded(pipe_input("fmt", "xmake create-package " .. package_name)),
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
            pipe_input("fmt, ,spdlog", "xmake create-package " .. package_name)
        )
    )
    luaunit.assertFalse(file_exists(join_path(package_directory(package_name), "xmake.lua")))
end

function TestScripts:testCreatePackageRejectsBackslashInDependencyName()
    local package_name = new_package_name()

    luaunit.assertFalse(
        command_succeeded(
            pipe_input("fmt, bad\\dependency", "xmake create-package " .. package_name)
        )
    )
    luaunit.assertFalse(file_exists(join_path(package_directory(package_name), "xmake.lua")))
end

function TestScripts:testCreatePackageRefusesToOverwriteExistingPackage()
    local package_name = new_package_name()
    local package_dir = package_directory(package_name)
    table.insert(self.generated_package_dirs, package_dir)

    luaunit.assertTrue(
        command_succeeded(pipe_input("fmt", "xmake create-package " .. package_name)),
        "initial package generation failed"
    )

    luaunit.assertFalse(
        command_succeeded(pipe_input("fmt", "xmake create-package " .. package_name)),
        "existing package was overwritten"
    )

    luaunit.assertTrue(file_exists(join_path(package_dir, "xmake.lua")))
end
