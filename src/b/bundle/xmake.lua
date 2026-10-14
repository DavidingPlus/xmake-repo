-- 分别验证静态链接和动态链接；库的构建模式跟随示例。使用不同的 ~ 标签，使同一版本的两种配置可以同时加载。
add_requires("bundle~static 2.1.0", {
    alias = "bundle-static",
    configs = {shared = false, debug = is_mode("debug")}
})
add_requires("bundle~shared 2.1.0", {
    alias = "bundle-shared",
    configs = {shared = true, debug = is_mode("debug")}
})

target("bundle")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("bundle-static")
target_end()

target("bundle-shared")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("bundle-shared")
target_end()
