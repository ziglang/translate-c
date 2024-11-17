#include <wchar.h>
#include <stdlib.h>
int main() {
    wchar_t wc = L'™';
    int utf16_char = u'™';
    int utf32_char = U'💯';
    if (wc != 8482) abort();
    if (utf16_char != 8482) abort();
    if (utf32_char != 128175) abort();
    unsigned char c = wc;
    if (c != 0x22) abort();
    c = utf32_char;
    if (c != 0xaf) abort();
    return 0;
}

// run
// expect=fail
