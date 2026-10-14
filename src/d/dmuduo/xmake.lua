-- Windows 平台不构建此目标。
if is_plat("windows") then
    return
end

-- 预编译包用 build_shared 选择静态或动态版本。
add_requires("dmuduo~static", {
    alias = "dmuduo-static",
    configs = {build_shared = false}
})
add_requires("dmuduo~shared", {
    alias = "dmuduo-shared",
    configs = {build_shared = true}
})

target("dmuduo-static")
    set_kind("binary")
    add_files("*.cpp")
    add_packages("dmuduo-static")
target_end()

target("dmuduo-shared")
    set_kind("binary")
    add_files("*.cpp")
    add_packages("dmuduo-shared")
target_end()
