package("bundle")
    set_homepage("https://github.com/r-lyeh-archived/bundle")
    set_description("An embeddable compression and archive library")
    set_license("Zlib")

    add_urls("https://github.com/r-lyeh-archived/bundle.git")
    -- 上游没有版本标签，将 2.1.0 固定到对应的提交。
    add_versions("2.1.0", "ae079276d7e91f193c0ef3e7f5425ccdf76c433e")

    on_load(function (package)
        -- 使用方的导入宏与库自身的导出宏分别设置。
        if package:config("shared") then
            package:add("defines", "BUNDLE_API=BUNDLE_API_IMPORT")
            if package:is_plat("windows") then
                package:addenv("PATH", "bin")
            elseif package:is_plat("linux") then
                package:addenv("LD_LIBRARY_PATH", path.join(package:installdir(), "lib"))
            end
        else
            package:add("defines", "BUNDLE_API=BUNDLE_API_STATIC")
        end
    end)

    on_install(function (package)
        -- 将内置 MCM 的旧类型别名改为标准名称，避免依赖 MSVC 扩展。
        io.replace("bundle.cpp", "std::ios_base::open_mode", "std::ios_base::openmode", {plain = true})
        -- clear_err 会修改成员状态，不能声明为 const；兼容 GCC 14 的模板检查。
        io.replace("bundle.cpp", "forceinline void clear_err() const", "forceinline void clear_err()", {plain = true})

        -- 上游没有 xmake.lua，安装时生成脚本，仅使用根目录的合并源码。
        io.writefile("xmake.lua", [[
            add_rules("mode.debug", "mode.release")
            target("bundle")
                set_kind("$(kind)")
                set_languages("cxx11")
                -- MSVC 没有独立的 C++11 模式，以 C++14 模式编译。
                on_config(function (target)
                    if target:has_tool("cxx", "cl", "clang_cl") then
                        target:set("languages", "cxx14")
                    end
                end)
                add_files("bundle.cpp")
                add_headerfiles("bundle.h")
                if is_kind("shared") then
                    add_defines("BUNDLE_API=BUNDLE_API_EXPORT")
                else
                    add_defines("BUNDLE_API=BUNDLE_API_STATIC")
                end
                if is_plat("windows") then
                    add_cxxflags("/bigobj", {tools = "cl"})
                end
                -- 内置 MCM 依赖 x86 的 SSE/SSE2 指令，ARM64 构建时禁用。
                if is_arch("arm64") then
                    add_defines("BUNDLE_NO_MCM")
                    -- 内置 ZPAQ 的模型字节表含负值，保持其对有符号 char 的假设。
                    add_cxxflags("-fsigned-char", {tools = {"gcc", "gxx", "clang", "clangxx"}})
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
                std::string original(8192, 'A');
                original[4096] = '\0';
                std::string packed, unpacked;
                if (!bundle::pack(bundle::LZ4, packed, original)) return 1;
                if (!bundle::unpack(unpacked, packed)) return 2;
                return original == unpacked ? 0 : 3;
            }
        ]]}, {
            includes = {"bundle.h", "string"},
            configs = {languages = package:is_plat("windows") and "c++14" or "c++11"},
            tryrun = not package:is_cross()
        }))
    end)
