add_requires("coroutine")

target("coroutine")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("coroutine")
target_end()
