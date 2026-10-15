package("cpp-base64")
    set_homepage("https://github.com/ReneNyffenegger/cpp-base64")
    set_description("Base64 encoding and decoding with C++")
    set_license("Zlib")

    add_urls("https://github.com/ReneNyffenegger/cpp-base64.git")
    -- 上游源码标注为 2.rc.09，但没有同名标签；固定到明确的提交。
    add_versions("2.rc.09", "951de609dbe27ce8864dfe47323c4ade96bee86e")

    if is_plat("windows") then
        -- 让 MSVC 使用方按实际语言标准启用头文件中的 string_view 接口。
        add_cxxflags("/Zc:__cplusplus", {tools = {"cl", "clang_cl"}})
    end

    on_load(function (package)
        if package:config("shared") then
            if package:is_plat("windows") then
                package:addenv("PATH", "bin")
            elseif package:is_plat("linux") then
                package:addenv("LD_LIBRARY_PATH", path.join(package:installdir(), "lib"))
            end
        end
    end)

    on_install(function (package)
        -- 上游只提供源码和测试用 Makefile，安装时生成库的构建脚本。
        io.writefile("xmake.lua", [[
            add_rules("mode.debug", "mode.release")
            target("cpp-base64")
                set_kind("$(kind)")
                -- 同时编译 string 与 string_view 接口，避免使用方链接时缺少符号。
                set_languages("cxx17")
                add_cxxflags("/Zc:__cplusplus", {tools = {"cl", "clang_cl"}})
                -- 上游注释使用 UTF-8，避免 MSVC 按本地代码页读取。
                add_cxxflags("/utf-8", {tools = {"cl", "clang_cl"}})
                add_files("base64.cpp")
                add_headerfiles("base64.h")
                if is_plat("windows") and is_kind("shared") then
                    -- 上游没有导出宏，由 XMake 从目标文件生成 DLL 导出表。
                    add_rules("utils.symbols.export_all")
                end
        ]])
        local configs = {
            kind = package:config("shared") and "shared" or "static"
        }
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            int main() {
                const std::string original("A\0B", 3);
                const std::string encoded = base64_encode(original);
                if (encoded != "QQBC" || base64_decode(encoded) != original) return 1;
                const std::string_view view(original.data(), original.size());
                if (base64_encode(view) != encoded) return 2;
                return base64_decode(std::string_view(encoded)) == original ? 0 : 3;
            }
        ]]}, {
            includes = {"base64.h", "string", "string_view"},
            configs = {languages = "c++17"},
            tryrun = not package:is_cross()
        }))
    end)
