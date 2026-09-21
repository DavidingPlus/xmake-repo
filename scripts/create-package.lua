-- 根据包名生成 packages/<首字母>/<包名>/xmake.lua。
--
-- 用法：
--     xmake create-package <name>
--
-- 例如：
--     xmake create-package foo

local function replace_placeholder(content, name, value)
    return content:gsub("{{" .. name .. "}}", function()
        return value
    end)
end

function main(name)
    assert(
        name and name:match("^[a-z0-9][a-z0-9%._%-]*$"),
        "package name must contain only lowercase letters, digits, '.', '_' or '-'."
    )

    local github_owner = assert(
        os.getenv("XMAKE_PACKAGE_GITHUB_OWNER"),
        "github owner is not configured; run `xmake create-package <name>` from the project root."
    )

    local project_dir = path.join(os.scriptdir(), "..")
    local template_file = path.join(os.scriptdir(), "template.lua")
    local package_dir = path.join(project_dir, "packages", name:sub(1, 1), name)
    local package_file = path.join(package_dir, "xmake.lua")

    assert(os.isfile(template_file), "package template does not exist: " .. template_file)
    assert(not os.isfile(package_file), "package file already exists: " .. package_file)

    local content = assert(io.readfile(template_file))
    content = replace_placeholder(content, "PACKAGE_NAME", name)
    content = replace_placeholder(content, "PACKAGE_DESCRIPTION", "The " .. name .. " package")
    content = replace_placeholder(content, "GITHUB_OWNER", github_owner)

    os.mkdir(package_dir)
    os.mkdir(path.join(package_dir, "versions"))

    local gitkeep_file = path.join(package_dir, "versions", ".gitkeep")

    io.writefile(package_file, content)
    io.writefile(gitkeep_file, "")

    print("generated " .. package_file)
    print("generated " .. gitkeep_file)
end
