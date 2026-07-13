add_requires("xmake-project")

target("xmake-project")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("xmake-project")
target_end()
