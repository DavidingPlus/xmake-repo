-- Windows 平台不构建此目标。
if is_plat("windows") then
    return
end

add_requires("dfiber")

target("dfiber")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dfiber")
target_end()
