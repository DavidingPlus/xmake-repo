-- 预编译包用 build_shared 选择静态或动态版本。
add_requires("dlog~static", {
    alias = "dlog-static",
    configs = {build_shared = false}
})
add_requires("dlog~shared", {
    alias = "dlog-shared",
    configs = {build_shared = true}
})

target("dlog-static")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dlog-static")
target_end()

target("dlog-shared")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dlog-shared")
target_end()
