#include <iostream>

#include <xmake-project/ltest.h>


#if defined(D_OS_WIN32)
#ifndef D_BUILD_SHARED
#error "The consumer must define D_BUILD_SHARED when using the Windows DLL"
#endif

#ifdef D_DLL_EXPORT
#error "The consumer must not define D_DLL_EXPORT"
#endif
#endif


int main()
{
    std::cout << LTest::foo() << std::endl;

    auto p = LTest().gee(3, 4);

    std::cout << p.first << std::endl;
    std::cout << p.second << std::endl;
}
