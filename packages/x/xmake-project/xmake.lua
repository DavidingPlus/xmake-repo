package("xmake-project")
    set_description("The xmake project template")

    on_source(function(package)
        local suffix = package:plat() .. "-" .. package:arch()

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
        local mode = package:debug() and "debug" or "release"

        os.cp(
            path.join(mode, "*"),
            package:installdir()
        )
    end)

    on_test(function(package)
        assert(os.isfile(
            path.join(package:installdir(), "config/config.h")
        ))
    end)
