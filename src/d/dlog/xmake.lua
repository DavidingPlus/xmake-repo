-- 预编译包用 build_shared 选择静态或动态版本。
add_requires("dlog~static", {
    alias = "dlog-static",
    configs = {build_shared = false}
})
add_requires("dlog~shared", {
    alias = "dlog-shared",
    configs = {build_shared = true}
})

target("dlog-static-1")
    set_kind("binary")
    add_files("main1.cpp")
    add_packages("dlog-static")
target_end()

target("dlog-shared-1")
    set_kind("binary")
    add_files("main1.cpp")
    add_packages("dlog-shared")
target_end()

target("dlog-static-2")
    set_kind("binary")
    add_files("main2.cpp")
    add_packages("dlog-static")
target_end()

target("dlog-shared-2")
    set_kind("binary")
    add_files("main2.cpp")
    add_packages("dlog-shared")
target_end()
