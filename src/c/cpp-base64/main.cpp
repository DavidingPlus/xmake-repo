#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

#include <base64.h>


int main()
{
    bool all_tests_passed = true;

    // 原始文本及其 Base64 参考值都以 UTF-8 字节为准。
    const std::string orig =
        "René Nyffenegger\n"
        "http://www.renenyffenegger.ch\n"
        "passion for data\n";

    std::string encoded = base64_encode(
        reinterpret_cast<const unsigned char *>(orig.c_str()), orig.length());
    std::string decoded = base64_decode(encoded);

    if (encoded != "UmVuw6kgTnlmZmVuZWdnZXIKaHR0cDovL3d3dy5yZW5lbnlmZmVuZWdnZXIuY2gKcGFzc2lvbiBmb3IgZGF0YQo=")
    {
        std::cout << "Encoding is wrong\n";
        all_tests_passed = false;
    }

    if (decoded != orig)
    {
        std::cout << "decoded != orig\n";
        all_tests_passed = false;
    }

    // 覆盖无填充、两个 = 和一个 = 的情况，参考值来自 https://www.base64encode.org/。
    std::string rest0_original = "abc";
    std::string rest0_reference = "YWJj";
    std::string rest0_encoded = base64_encode(
        reinterpret_cast<const unsigned char *>(rest0_original.c_str()), rest0_original.length());
    std::string rest0_decoded = base64_decode(rest0_encoded);

    if (rest0_decoded != rest0_original)
    {
        std::cout << "rest0_decoded != rest0_original\n";
        all_tests_passed = false;
    }

    if (rest0_reference != rest0_encoded)
    {
        std::cout << "rest0_reference != rest0_encoded\n";
        all_tests_passed = false;
    }

    std::string rest1_original = "abcd";
    std::string rest1_reference = "YWJjZA==";
    std::string rest1_encoded = base64_encode(
        reinterpret_cast<const unsigned char *>(rest1_original.c_str()), rest1_original.length());
    std::string rest1_decoded = base64_decode(rest1_encoded);

    if (rest1_decoded != rest1_original)
    {
        std::cout << "rest1_decoded != rest1_original\n";
        all_tests_passed = false;
    }

    if (rest1_reference != rest1_encoded)
    {
        std::cout << "rest1_reference != rest1_encoded\n";
        all_tests_passed = false;
    }

    std::string rest2_original = "abcde";
    std::string rest2_reference = "YWJjZGU=";
    std::string rest2_encoded = base64_encode(
        reinterpret_cast<const unsigned char *>(rest2_original.c_str()), rest2_original.length());
    std::string rest2_decoded = base64_decode(rest2_encoded);

    if (rest2_decoded != rest2_original)
    {
        std::cout << "rest2_decoded != rest2_original\n";
        all_tests_passed = false;
    }

    if (rest2_reference != rest2_encoded)
    {
        std::cout << "rest2_reference != rest2_encoded\n";
        all_tests_passed = false;
    }

    // 回归测试：17 字节数据在 URL 模式下需要一个 . 填充。
    std::string a17_orig = "aaaaaaaaaaaaaaaaa";
    std::string a17_encoded = base64_encode(a17_orig, false);
    std::string a17_encoded_url = base64_encode(a17_orig, true);

    if (a17_encoded != "YWFhYWFhYWFhYWFhYWFhYWE=")
    {
        std::cout << "Failed to encode a17\n";
        all_tests_passed = false;
    }

    if (a17_encoded_url != "YWFhYWFhYWFhYWFhYWFhYWE.")
    {
        std::cout << "Failed to encode a17 (url)\n";
        all_tests_passed = false;
    }

    if (base64_decode(a17_encoded_url) != a17_orig)
    {
        std::cout << "Failed to decode a17 (url)\n";
        all_tests_passed = false;
    }

    if (base64_decode(a17_encoded) != a17_orig)
    {
        std::cout << "Failed to decode a17 (no url)\n";
        all_tests_passed = false;
    }

    // 检查普通模式的 +/ 字符和 URL 模式的 -_ 字符。
    std::string s_6364 = "\x03"
                         "\xef"
                         "\xff"
                         "\xf9";
    std::string s_6364_encoded = base64_encode(s_6364, false);
    std::string s_6364_encoded_url = base64_encode(s_6364, true);

    if (s_6364_encoded != "A+//+Q==")
    {
        std::cout << "Failed to encode_6364 (no url)\n";
        all_tests_passed = false;
    }

    if (s_6364_encoded_url != "A-__-Q..")
    {
        std::cout << "Failed to encode_6364 (url)\n";
        all_tests_passed = false;
    }

    if (base64_decode(s_6364_encoded) != s_6364)
    {
        std::cout << "Failed to decode s_6364_encoded\n";
        all_tests_passed = false;
    }

    if (base64_decode(s_6364_encoded_url) != s_6364)
    {
        std::cout << "Failed to decode s_6364_encoded_url\n";
        all_tests_passed = false;
    }

    std::string numbers =
        "one two three four five six seven eight nine ten eleven twelve "
        "thirteen fourteen fivteen sixteen seventeen eighteen nineteen "
        "twenty twenty-one";
    std::string encoded_mime = base64_encode_mime(numbers);
    std::string encoded_mime_expected =
        "b25lIHR3byB0aHJlZSBmb3VyIGZpdmUgc2l4IHNldmVuIGVpZ2h0IG5pbmUgdGVuIGVsZXZlbiB0\n"
        "d2VsdmUgdGhpcnRlZW4gZm91cnRlZW4gZml2dGVlbiBzaXh0ZWVuIHNldmVudGVlbiBlaWdodGVl\n"
        "biBuaW5ldGVlbiB0d2VudHkgdHdlbnR5LW9uZQ==";

    if (encoded_mime != encoded_mime_expected)
    {
        std::cout << "Failed: base64_encode_mime\n";
        all_tests_passed = false;
    }

    // MIME 编码包含换行，解码时需要开启 remove_linebreaks。
    std::string decoded_mime = base64_decode(encoded_mime, true);
    if (decoded_mime != numbers)
    {
        std::cout << "Failed: base64_decode(..., true)\n";
        all_tests_passed = false;
    }

    // 检查省略尾部填充的输入，以及空输入。
    std::string unpadded_input = "YWJjZGVmZw"; // 省略 ==。
    std::string unpadded_decoded = base64_decode(unpadded_input);
    if (unpadded_decoded != "abcdefg")
    {
        std::cout << "Failed to decode unpadded input " << unpadded_input << '\n';
        all_tests_passed = false;
    }

    unpadded_input = "YWJjZGU"; // 省略 =。
    unpadded_decoded = base64_decode(unpadded_input);
    if (unpadded_decoded != "abcde")
    {
        std::cout << "Failed to decode unpadded input " << unpadded_input << '\n';
        std::cout << unpadded_decoded << '\n';
        all_tests_passed = false;
    }

    unpadded_input = "";
    unpadded_decoded = base64_decode(unpadded_input);
    if (unpadded_decoded != "")
    {
        std::cout << "Failed to decode unpadded input " << unpadded_input << '\n';
        std::cout << unpadded_decoded << '\n';
        all_tests_passed = false;
    }

    unpadded_input = "YQ";
    unpadded_decoded = base64_decode(unpadded_input);
    if (unpadded_decoded != "a")
    {
        std::cout << "Failed to decode unpadded input " << unpadded_input << '\n';
        std::cout << unpadded_decoded << '\n';
        all_tests_passed = false;
    }

    unpadded_input = "YWI";
    unpadded_decoded = base64_decode(unpadded_input);
    if (unpadded_decoded != "ab")
    {
        std::cout << "Failed to decode unpadded input " << unpadded_input << '\n';
        std::cout << unpadded_decoded << '\n';
        all_tests_passed = false;
    }

    // 回归测试：长度为 1 的非法输入应由 at() 检查并抛出越界异常。
    try
    {
        std::string not_null_terminated = std::string(1, 'a');
        std::string not_null_decoded = base64_decode(not_null_terminated);

        std::cout << "Expected a std::out_of_range exception\n";
        all_tests_passed = false;
    }
    catch (const std::out_of_range &)
    {
    }

#if __cplusplus >= 201703L
    // 保留 string_view 输入；返回的字符串需要持有存储，不能用视图引用临时对象。
    std::string_view sv_orig = "foobarbaz";
    std::string sv_encoded = base64_encode(sv_orig);

    if (sv_encoded != "Zm9vYmFyYmF6")
    {
        std::cout << "Failed to encode with string_view\n";
        all_tests_passed = false;
    }

    std::string sv_decoded = base64_decode(std::string_view(sv_encoded));
    if (sv_decoded != sv_orig)
    {
        std::cout << "Failed to decode with string_view\n";
        all_tests_passed = false;
    }
#endif

    if (all_tests_passed)
    {
        std::cout << "All Base64 tests passed\n";
        return 0;
    }
    else
    {
        std::cout << "All Base64 tests did not pass\n";
        return 1;
    }
}
