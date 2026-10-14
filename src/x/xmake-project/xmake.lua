-- 预编译包用 build_shared 选择静态或动态版本。
add_requires("xmake-project~static", {
    alias = "xmake-project-static",
    configs = {build_shared = false}
})
add_requires("xmake-project~shared", {
    alias = "xmake-project-shared",
    configs = {build_shared = true}
})

target("xmake-project-static")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("xmake-project-static")
target_end()

target("xmake-project-shared")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("xmake-project-shared")
target_end()
