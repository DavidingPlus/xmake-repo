-- 2.rc.09 不能参与 XMake 的 latest 版本选择，需要显式指定。分别验证静态链接和动态链接；库的构建模式跟随示例。
add_requires("cpp-base64~static 2.rc.09", {
    alias = "cpp-base64-static",
    configs = {shared = false, debug = is_mode("debug")}
})
add_requires("cpp-base64~shared 2.rc.09", {
    alias = "cpp-base64-shared",
    configs = {shared = true, debug = is_mode("debug")}
})

target("cpp-base64-static")
    set_kind("binary")
    add_files("main.cpp")
    -- 上游测试的参考值基于 UTF-8，需要同时指定源码与执行字符集。
    add_cxxflags("/utf-8", {tools = {"cl", "clang_cl"}})
    add_packages("cpp-base64-static")
target_end()

target("cpp-base64-shared")
    set_kind("binary")
    add_files("main.cpp")
    add_cxxflags("/utf-8", {tools = {"cl", "clang_cl"}})
    add_packages("cpp-base64-shared")
target_end()
