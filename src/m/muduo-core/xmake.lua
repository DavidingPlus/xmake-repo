-- Windows 平台不构建此目标。
if is_plat("windows") then
    return
end

add_requires("muduo-core")

target("muduo-core")
    set_kind("binary")
    add_files("*.cpp")
    add_packages("muduo-core")
target_end()
