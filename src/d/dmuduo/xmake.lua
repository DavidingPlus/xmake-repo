-- Windows 平台不构建此目标。
if is_plat("windows") then
    return
end

add_requires("dmuduo")

target("dmuduo")
    set_kind("binary")
    add_files("*.cpp")
    add_packages("dmuduo")
target_end()
