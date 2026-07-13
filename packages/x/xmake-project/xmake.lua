package("xmake-project")
    set_description("The xmake project template")

    on_source(function(package)
        local suffix = package:plat() .. "-" .. package:arch()
        local runtime = package:config("runtimes")

        if package:plat() == "windows" then
            local runtime = package:config("runtimes")

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

    on_install(function(package)
        os.cp("*", package:installdir())
    end)

    on_test(function(package)
        assert(os.isfile(
            path.join(package:installdir(), "config/config.h")
        ))
    end)
