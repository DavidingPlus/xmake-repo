#include <cassert>
#include <iostream>
#include <string>
#include <vector>

#include <bundle.h>


int main()
{
    // 构造重复文本数据，用于测试各压缩算法。
    std::string original("There's a lady who's sure all that glitters is gold");
    for (int i = 0; i < 18; ++i) original += original + std::string(i + 1, 32 + i);

    // 逐一压缩、解压，并验证数据完整性。
    const std::vector<unsigned> algorithms{
        bundle::RAW, bundle::SHOCO, bundle::LZ4F, bundle::MINIZ, bundle::LZIP, bundle::LZMA20,
        bundle::ZPAQ, bundle::LZ4, bundle::BROTLI9, bundle::ZSTD, bundle::LZMA25,
        bundle::BSC, bundle::BROTLI11, bundle::SHRINKER, bundle::CSC20, bundle::BCM,
        bundle::ZLING, bundle::MCM, bundle::TANGELO, bundle::ZMOLLY, bundle::CRUSH, bundle::LZJB};

    for (unsigned algorithm : algorithms)
    {
        std::string packed = bundle::pack(algorithm, original);
        std::string unpacked = bundle::unpack(packed);

        std::cout << original.size() << " -> " << packed.size()
                  << " bytes (" << bundle::name_of(algorithm) << ")" << std::endl;
        assert(original == unpacked);
    }

    std::cout << "All ok." << std::endl;
}
