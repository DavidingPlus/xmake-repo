-- 根据包名生成 packages/<首字母>/<包名>/xmake.lua。
--
-- 用法：
--     xmake create-package <name>
--
-- 例如：
--     xmake create-package foo

-- 使用回调形式替换占位符，避免替换值中的 '%' 被 gsub 当成特殊字符处理。
local function replace_placeholder(content, name, value)
    return content:gsub("{{" .. name .. "}}", function()
        return value
    end)
end

function main(name)
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

    -- 将模板中的元信息占位符替换为当前包名和仓库 owner。
    local content = assert(io.readfile(template_file))
    content = replace_placeholder(content, "PACKAGE_NAME", name)
    content = replace_placeholder(content, "PACKAGE_DESCRIPTION", "The " .. name .. " package")
    content = replace_placeholder(content, "GITHUB_OWNER", github_owner)

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
