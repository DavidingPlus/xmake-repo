#include <iostream>
#include <string>

#include <bundle.h>


int main()
{
    // std::string 按长度保存二进制数据，包含零字节也应完整还原。
    std::string original(32768, 'A');
    for (std::size_t i = 0; i < original.size(); i += 256) original[i] = '\0';

    const unsigned algorithms[] = {bundle::LZ4, bundle::ZSTD, bundle::MINIZ};
    for (unsigned algorithm : algorithms)
    {
        std::string packed;
        std::string unpacked;

        if (!bundle::pack(algorithm, packed, original))
        {
            std::cerr << "Compression failed: " << bundle::name_of(algorithm) << '\n';
            return 1;
        }

        if (!bundle::unpack(unpacked, packed) || unpacked != original)
        {
            std::cerr << "Round trip failed: " << bundle::name_of(algorithm) << '\n';
            return 2;
        }

        std::cout << bundle::name_of(algorithm) << ": "
                  << original.size() << " -> " << packed.size()
                  << " bytes; round trip passed\n";
    }
}
