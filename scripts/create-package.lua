-- 根据包名生成 packages/<首字母>/<包名>/xmake.lua。
--
-- 用法：
--     xmake create-package <name>
--     xmake create-package <name> '<package-metadata-json>'
--     xmake create-package foo
--     xmake create-package foo '{\"package_name\":\"foo\",\"macro_prefix\":\"FOO\",\"dependencies\":{\"common\":[\"fmt\"],\"windows\":[],\"linux\":[]}}'
--
-- 手动创建时依次询问宏前缀、通用依赖、Windows 依赖和 Linux 依赖；宏前缀留空时按包名推导。
-- 自动创建时将 dlog 生成的 package-metadata.json 内容（注意是 json 字符串内容而不是 json 路径）作为第二个参数传入。

-- 使用回调形式替换占位符，避免替换值中的 '%' 被 gsub 当成特殊字符处理。
local function replace_placeholder(content, name, value)
    return content:gsub("{{" .. name .. "}}", function()
        return value
    end)
end

-- 手动执行时按平台询问依赖；自动创建时由命令行 JSON 参数提供分组依赖。
local function read_dependencies(platform)
    local platform_names = {common = "跨平台通用", windows = " Windows ", linux = " Linux "}
    print("请输入" .. platform_names[platform] .. "依赖（可选，多个依赖用英文逗号分隔；直接回车表示无依赖）：")
    io.flush()
    local input = io.read()
    local dependencies = {}
    for dependency in (input or ""):gmatch("[^,]+") do
        dependency = dependency:gsub("^%s+", ""):gsub("%s+$", "")
        assert(
            dependency ~= "" and not dependency:match("[\"\\\r\n]"),
            "依赖项不能包含引号、反斜杠或换行符。"
        )
        table.insert(dependencies, dependency)
    end
    return dependencies
end

local function default_macro_prefix(package_name)
    return package_name:upper():gsub("%-", "_")
end

local function read_macro_prefix(package_name)
    local default = default_macro_prefix(package_name)
    print("请输入宏前缀（直接回车使用默认值：" .. default .. "）：")
    io.flush()
    local macro_prefix = io.read() or ""
    macro_prefix = macro_prefix:gsub("^%s+", ""):gsub("%s+$", "")
    if macro_prefix == "" then
        return default
    end

    assert(
        macro_prefix:match("^[A-Z][A-Z0-9_]*$"),
        "宏前缀只能包含大写英文字母、数字和下划线，且需以大写字母开头。"
    )
    return macro_prefix
end

local function read_package_configuration(metadata_json, package_name)
    local groups
    local macro_prefix
    if metadata_json then
        import("core.base.json")
        local metadata = json.decode(metadata_json)
        assert(type(metadata) == "table", "元数据必须是 JSON 对象。")
        assert(metadata.package_name == package_name, "元数据中的 package_name 必须与命令行包名一致。")

        groups = metadata.dependencies
        macro_prefix = metadata.macro_prefix
        assert(
            type(macro_prefix) == "string"
                and macro_prefix:match("^[A-Z][A-Z0-9_]*$"),
            "元数据中的 macro_prefix 必须是合法的大写宏前缀。"
        )
    else
        -- 包名通过命令行提供；接下来依次询问宏前缀和三组依赖。
        macro_prefix = read_macro_prefix(package_name)
        groups = {}
        groups.common = read_dependencies("common")
        groups.windows = read_dependencies("windows")
        groups.linux = read_dependencies("linux")
    end

    assert(type(groups) == "table", "元数据中的 dependencies 必须是 JSON 对象。")
    for _, platform in ipairs({"common", "windows", "linux"}) do
        local dependencies = groups[platform] or {}
        assert(type(dependencies) == "table", "依赖分组必须是数组：" .. platform)
        for _, dependency in ipairs(dependencies) do
            assert(
                type(dependency) == "string"
                    and dependency ~= ""
                    and not dependency:match("[,\"\\\r\n]"),
                "依赖项无效：" .. platform
            )
        end
        groups[platform] = dependencies
    end
    return groups, macro_prefix
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

function main(name, metadata_json)
    -- 规定包名使用小写字母和数字，单词之间用单个连字符（-）分隔。
    assert(
        type(name) == "string"
            and name:match("^[a-z][a-z0-9%-]*$")
            and name:sub(1, 1) ~= "-"
            and name:sub(-1) ~= "-"
            and not name:find("--", 1, true),
        "包名必须以小写字母开头，并使用小写字母、数字和单个连字符分隔单词。"
    )

    -- owner 由根目录 xmake.lua 通过环境变量传入，用户命令只需要提供 name。
    local github_owner = assert(
        os.getenv("XMAKE_PACKAGE_GITHUB_OWNER"),
        "尚未配置 GitHub owner，请从项目根目录运行 xmake create-package。"
    )

    -- 脚本位于 scripts/，生成结果放回仓库根目录下的 packages/<首字母>/<包名>/。
    local project_dir = path.join(os.scriptdir(), "..")
    local template_file = path.join(os.scriptdir(), "template.lua")
    local package_dir = path.join(project_dir, "packages", name:sub(1, 1), name)
    local package_file = path.join(package_dir, "xmake.lua")

    -- 生成前先检查模板，并拒绝覆盖已有包配方。
    assert(os.isfile(template_file), "包模板不存在：" .. template_file)
    assert(not os.isfile(package_file), "包配置已存在，拒绝覆盖：" .. package_file)

    local dependencies, macro_prefix = read_package_configuration(metadata_json, name)
    local package_deps = format_common_dependencies(dependencies.common)
    local package_platform_deps = format_platform_dependencies(dependencies)

    -- 将模板中的元信息占位符替换为当前包名和仓库 owner。
    local content = assert(io.readfile(template_file))
    content = replace_placeholder(content, "PACKAGE_NAME", name)
    -- 使用完整元数据中的 macro_prefix 填充包模板。
    content = replace_placeholder(content, "MACRO_PREFIX", macro_prefix)
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

    print("已生成包配置：" .. package_file)
    print("已生成版本目录占位文件：" .. gitkeep_file)
end
