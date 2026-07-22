add_rules("mode.debug", "mode.release")


-- 为兼容 CI 场景，PR 构建时使用 checkout 后的本地 xmake-repo 仓库，以便测试 PR 分支中 xmake-repo 的修改。
-- 本地开发环境默认使用远端仓库。
local xmake_repo = "https://github.com/DavidingPlus/xmake-repo.git"

if os.getenv("CI_XMAKE_REPO") then
    xmake_repo = os.getenv("CI_XMAKE_REPO")
end

add_repositories("davidingplus " .. xmake_repo)


includes("src")
