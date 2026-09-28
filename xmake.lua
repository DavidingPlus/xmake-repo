add_rules("mode.debug", "mode.release")


-- 为兼容 CI 场景，PR 构建时使用 checkout 后的本地 xmake-repo 仓库，以便测试 PR 分支中 xmake-repo 的修改。
-- 本地开发环境默认使用远端仓库。
local github_owner = "DavidingPlus"
local github_repository = "xmake-repo"
-- 仓库地址由 owner 和仓库名拼接，修改身份信息时只需要改上面的变量。
local xmake_repo = "https://github.com/" .. github_owner .. "/" .. github_repository .. ".git"

-- CI 在测试的过程中，需要设置为本地当前目录而非远端仓库。
if os.getenv("CI_XMAKE_REPO") then
    xmake_repo = os.getenv("CI_XMAKE_REPO")
end

add_repositories("davidingplus " .. xmake_repo)


includes("src")


-- 注册 xmake create-package <name> [package-metadata-json] 命令，用于生成新包。
-- 用法：
--     xmake create-package <name>
--     xmake create-package <name> '<package-metadata-json>'
--     xmake create-package foo
--     xmake create-package foo '{\"package_name\":\"foo\",\"macro_prefix\":\"FOO\",\"dependencies\":{\"common\":[\"fmt\"],\"windows\":[],\"linux\":[]}}'
--
-- 手动创建时依次询问宏前缀、通用依赖、Windows 依赖和 Linux 依赖；宏前缀留空时按包名推导。
-- 自动创建时将 dlog 生成的 package-metadata.json 内容（注意是 json 字符串内容而不是 json 路径）作为第二个参数传入。
task("create-package")
    set_category("plugin")

    on_run(function()
        import("core.base.option")

        -- set_menu 中的可变参数会以 contents 数组传入：包名和可选的依赖 JSON。
        local contents = option.get("contents") or {}
        assert(
            #contents == 1 or #contents == 2,
            "usage: xmake create-package <name> [package-metadata-json]"
        )

        -- 通过环境变量把根配置中的 owner 传给子进程，避免生成脚本重复写死。
        os.setenv("XMAKE_PACKAGE_GITHUB_OWNER", github_owner)

        -- 复用独立生成脚本；任务本身只负责接收命令行参数和传递配置。
        local args = {
            "lua",
            path.join(os.scriptdir(), "scripts/create-package.lua"),
            contents[1]
        }
        if contents[2] then table.insert(args, contents[2]) end
        os.execv("xmake", args)
    end)

    -- set_menu 让 task 可以直接从命令行调用。
    set_menu {
        usage = "xmake create-package <name> [package-metadata-json]",
        description = "Create a new package.",
        options = {
            {nil, "contents", "vs", nil, "Package name"}
        }
    }

-- 使用标准 Lua 运行时执行 LuaUnit 测试。LUA 环境变量可用于指定 Lua 可执行文件。
task("luaunit")
    set_category("plugin")

    on_run(function()
        import("lib.detect.find_tool")

        local lua = os.getenv("LUA")
        if not lua then
            local lua_tool = find_tool("lua")
            assert(
                lua_tool,
                "Lua runtime was not found; install Lua 5.1+ or set the LUA environment variable."
            )
            lua = lua_tool.program
        end

        os.execv(
            lua,
            {
                path.join(os.projectdir(), "tests", "run.lua")
            }
        )
    end)

    set_menu {
        usage = "xmake luaunit",
        description = "Run LuaUnit tests."
    }
