package("xmake-project")
    set_description("The xmake project template")

    -- XMake 会把内置 shared=false 视为全局默认值并省略。如果直接把 shared 的包默认值改成 true，外层传入的 shared=false 可能会丢失。因此使用独立配置保存包的默认值，再同步给 shared。
    add_configs("build_shared", {
        description = "Build the shared library.",
        default = true,
        type = "boolean"
    })

    on_source(function(package)
        local suffix = package:plat() .. "-" .. package:arch()
        local runtime = package:config("runtimes")

        if package:is_plat("windows") then
            -- 如果用户没有指定 runtime，根据当前构建模式选择默认 runtime。
            if nil == runtime then
                if is_mode("debug") then
                    runtime = "MDd"
                else
                    runtime = "MD"
                end
            end

            suffix = suffix .. "-" .. runtime
        end

        -- 动态库和静态库都使用显式后缀。
        suffix = suffix .. (package:config("build_shared") and "-shared" or "-static")

        package:add(
            "urls",
            "https://github.com/DavidingPlus/xmake-project-template/"
            .. "releases/download/v$(version)/"
            .. "xmake-project-v$(version)-" .. suffix .. ".tar.gz"
        )

        package:add(
            "versionfiles",
            "versions/" .. suffix .. ".txt"
        )
    end)

    on_load(function(package)
        local build_shared = package:config("build_shared")

        -- 让 XMake 后续按动态库/静态库处理包的链接信息。
        package:config_set("shared", build_shared)

        if build_shared and package:is_plat("linux") then
            -- Linux 动态库位于安装目录的 lib/ 下。
            package:addenv(
                "LD_LIBRARY_PATH",
                path.join(package:installdir(), "lib")
            )
        elseif build_shared and package:is_plat("windows") then
            -- Windows DLL 位于安装目录的 bin/ 下。将其加入 PATH，保证依赖该包的可执行程序能够找到 dll 文件。
            package:addenv("PATH", "bin")

            -- 使用方链接的是 Windows DLL，需要让头文件使用 dllimport。
            package:add("defines", "D_BUILD_SHARED")
        end
    end)

    on_install(function(package)
        os.cp("*", package:installdir())

        package:add("includedirs", "include")
    end)

    on_test(function(package)
        assert(os.isfile(
            path.join(package:installdir(), "include/xmake-project/config.h")
        ))
    end)
