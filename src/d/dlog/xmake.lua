add_requires("dlog")

target("dlog")
    set_kind("binary")
    add_files("main.cpp")
    add_packages("dlog")
target_end()
