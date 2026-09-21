add_rules("mode.debug", "mode.release")


-- 为兼容 CI 场景，PR 构建时使用 checkout 后的本地 xmake-repo 仓库，以便测试 PR 分支中 xmake-repo 的修改。
-- 本地开发环境默认使用远端仓库。
local github_owner = "DavidingPlus"
local github_repository = "xmake-repo"
local xmake_repo = "https://github.com/" .. github_owner .. "/" .. github_repository .. ".git"

-- CI 在测试的过程中，需要设置为本地当前目录而非远端仓库。
if os.getenv("CI_XMAKE_REPO") then
    xmake_repo = os.getenv("CI_XMAKE_REPO")
end

add_repositories("davidingplus " .. xmake_repo)


includes("src")


task("create-package")
    set_category("plugin")

    on_run(function()
        import("core.base.option")

        local contents = option.get("contents") or {}
        assert(
            #contents == 1,
            "usage: xmake create-package <name>"
        )

        os.setenv("XMAKE_PACKAGE_GITHUB_OWNER", github_owner)

        os.execv(
            "xmake",
            {
                "lua",
                path.join(os.scriptdir(), "scripts/create-package.lua"),
                contents[1]
            }
        )
    end)

    set_menu {
        usage = "xmake create-package <name>",
        description = "Create a new package.",
        options = {
            {nil, "contents", "vs", nil, "Package name"}
        }
    }
