-- 根据包名生成 packages/<首字母>/<包名>/xmake.lua。
--
-- 用法：
--     xmake create-package <name>
--     xmake create-package <name> '<dependencies-json>'
--
-- 手动创建时会依次询问 common、windows、linux 依赖；每项可留空。
-- 自动创建时可把三组依赖作为第二个参数传入 JSON。
-- 例如：
--     xmake create-package foo

-- 使用回调形式替换占位符，避免替换值中的 '%' 被 gsub 当成特殊字符处理。
local function replace_placeholder(content, name, value)
    return content:gsub("{{" .. name .. "}}", function()
        return value
    end)
end

-- 手动执行时按平台询问依赖；自动创建时由命令行 JSON 参数提供分组依赖。
local function read_dependencies(platform)
    print(platform:sub(1, 1):upper() .. platform:sub(2)
        .. " dependencies (optional, comma-separated; press Enter for none):")
    local input = io.read()
    local dependencies = {}
    for dependency in (input or ""):gmatch("[^,]+") do
        dependency = dependency:gsub("^%s+", ""):gsub("%s+$", "")

        -- 禁止引号、反斜杠和换行，避免用户输入破坏生成的 Lua 语法。
        assert(
            dependency ~= "" and not dependency:match("[\"\\\r\n]"),
            "dependency names cannot contain quotes, backslashes or newlines."
        )

        table.insert(dependencies, dependency)
    end

    return dependencies
end

local function read_dependency_groups(dependencies_json)
    local groups
    if dependencies_json then
        import("core.base.json")
        groups = json.decode(dependencies_json)
    else
        groups = {}
        groups.common = read_dependencies("common")
        groups.windows = read_dependencies("windows")
        groups.linux = read_dependencies("linux")
    end

    assert(type(groups) == "table", "dependencies must be a JSON object")
    for _, platform in ipairs({"common", "windows", "linux"}) do
        local dependencies = groups[platform] or {}
        assert(type(dependencies) == "table", "dependencies." .. platform .. " must be an array")
        for _, dependency in ipairs(dependencies) do
            assert(
                type(dependency) == "string"
                    and dependency ~= ""
                    and not dependency:match("[,\"\\\r\n]"),
                "invalid dependency in " .. platform
            )
        end
        groups[platform] = dependencies
    end
    return groups
end

local function format_common_dependencies(dependencies)
    if #dependencies == 0 then return "" end
    local quoted_dependencies = {}
    for _, dependency in ipairs(dependencies) do
        table.insert(quoted_dependencies, "\"" .. dependency .. "\"")
    end
    return "add_deps(" .. table.concat(quoted_dependencies, ", ") .. ")"
end

local function format_platform_dependencies(platform_dependencies)
    local lines = {}
    for _, platform in ipairs({"windows", "linux"}) do
        local dependencies = platform_dependencies[platform]
        if #dependencies > 0 then
            local quoted_dependencies = {}
            for _, dependency in ipairs(dependencies) do
                table.insert(quoted_dependencies, '"' .. dependency .. '"')
            end
            table.insert(lines, 'if is_plat("' .. platform .. '") then')
            table.insert(lines, "    add_deps(" .. table.concat(quoted_dependencies, ", ") .. ")")
            table.insert(lines, "end")
        end
    end
    return table.concat(lines, "\n    ")
end

function main(name, dependencies_json)
    -- 包名同时用于目录名、包名、仓库名和压缩包前缀，因此限制为常见的小写包名格式。
    assert(
        name and name:match("^[a-z0-9][a-z0-9%._%-]*$"),
        "package name must contain only lowercase letters, digits, '.', '_' or '-'."
    )

    -- owner 由根目录 xmake.lua 通过环境变量传入，用户命令只需要提供 name。
    local github_owner = assert(
        os.getenv("XMAKE_PACKAGE_GITHUB_OWNER"),
        "github owner is not configured; run `xmake create-package <name>` from the project root."
    )

    -- 脚本位于 scripts/，生成结果放回仓库根目录下的 packages/<首字母>/<包名>/。
    local project_dir = path.join(os.scriptdir(), "..")
    local template_file = path.join(os.scriptdir(), "template.lua")
    local package_dir = path.join(project_dir, "packages", name:sub(1, 1), name)
    local package_file = path.join(package_dir, "xmake.lua")

    -- 生成前先检查模板，并拒绝覆盖已有包配方。
    assert(os.isfile(template_file), "package template does not exist: " .. template_file)
    assert(not os.isfile(package_file), "package file already exists: " .. package_file)

    local dependencies = read_dependency_groups(dependencies_json)
    local package_deps = format_common_dependencies(dependencies.common)
    local package_platform_deps = format_platform_dependencies(dependencies)

    -- 将模板中的元信息占位符替换为当前包名和仓库 owner。
    local content = assert(io.readfile(template_file))
    content = replace_placeholder(content, "PACKAGE_NAME", name)
    content = replace_placeholder(content, "PACKAGE_DESCRIPTION", "The " .. name .. " package")
    content = replace_placeholder(content, "GITHUB_OWNER", github_owner)
    content = replace_placeholder(content, "PACKAGE_DEPS", package_deps)
    content = replace_placeholder(content, "PACKAGE_PLATFORM_DEPS", package_platform_deps)

    -- 同时创建版本摘要文件目录，保证新包可以直接补充版本信息。
    os.mkdir(package_dir)
    os.mkdir(path.join(package_dir, "versions"))

    local gitkeep_file = path.join(package_dir, "versions", ".gitkeep")

    -- 写入包配方和空的 .gitkeep，让 versions 目录可以被 Git 保留。
    io.writefile(package_file, content)
    io.writefile(gitkeep_file, "")

    print("generated " .. package_file)
    print("generated " .. gitkeep_file)
end
