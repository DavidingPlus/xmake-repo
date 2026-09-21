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


-- 注册 `xmake create-package <name>` 命令，用于生成新包的基础目录和配方。
task("create-package")
    set_category("plugin")

    on_run(function()
        import("core.base.option")

        -- set_menu 中的可变参数会以 contents 数组传入，这里要求用户只提供包名。
        local contents = option.get("contents") or {}
        assert(
            #contents == 1,
            "usage: xmake create-package <name>"
        )

        -- 通过环境变量把根配置中的 owner 传给子进程，避免生成脚本重复写死。
        os.setenv("XMAKE_PACKAGE_GITHUB_OWNER", github_owner)

        -- 复用独立生成脚本；任务本身只负责接收命令行参数和传递配置。
        os.execv(
            "xmake",
            {
                "lua",
                path.join(os.scriptdir(), "scripts/create-package.lua"),
                contents[1]
            }
        )
    end)

    -- set_menu 让 task 可以直接从命令行调用。
    set_menu {
        usage = "xmake create-package <name>",
        description = "Create a new package.",
        options = {
            {nil, "contents", "vs", nil, "Package name"}
        }
    }
