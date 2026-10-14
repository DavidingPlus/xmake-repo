-- Windows 平台不构建此目标。
if is_plat("windows") then
    return
end

-- 预编译包用 build_shared 选择静态或动态版本。
add_requires("dfiber~static", {
    alias = "dfiber-static",
    configs = {build_shared = false}
})
add_requires("dfiber~shared", {
    alias = "dfiber-shared",
    configs = {build_shared = true}
})

target("dfiber-static")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dfiber-static")
target_end()

target("dfiber-shared")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dfiber-shared")
target_end()
