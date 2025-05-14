#include <stdlib.h>
#include <stdint.h>
#include <wchar.h>
int main(void) {
    const wchar_t *wide_str = L"wide";
    const wchar_t wide_hello[] = L"hello";
    if (wcslen(wide_str) != 4) abort();
    if (wcslen(L"literal") != 7) abort();
    if (wcscmp(wide_hello, L"hello") != 0) abort();

    const uint16_t *u16_str = u"wide";
    const uint16_t u16_hello[] = u"hello";
    if (u16_str[3] != u'e' || u16_str[4] != 0) abort();
    if (u16_hello[4] != u'o' || u16_hello[5] != 0) abort();

    const uint32_t *u32_str = U"wide";
    const uint32_t u32_hello[] = U"hello";
    if (u32_str[3] != U'e' || u32_str[4] != 0) abort();
    if (u32_hello[4] != U'o' || u32_hello[5] != 0) abort();
    return 0;
}

// run
