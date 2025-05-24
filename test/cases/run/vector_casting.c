#include <stdlib.h>
#include <stdint.h>
typedef int8_t __v8qi __attribute__((__vector_size__(8)));
typedef uint8_t __v8qu __attribute__((__vector_size__(8)));
int main(int argc, char**argv) {
    __v8qi signed_vector = { 1, 2, 3, 4, -1, -2, -3,-4};

    uint64_t big_int = (uint64_t) signed_vector;
    if (big_int != 0x01020304FFFEFDFCULL && big_int != 0xFCFDFEFF04030201ULL) abort();
    __v8qu unsigned_vector = (__v8qu) big_int;
    for (int i = 0; i < 8; i++) {
        if (unsigned_vector[i] != (uint8_t)signed_vector[i] && unsigned_vector[i] != (uint8_t)signed_vector[7 - i]) abort();
    }
    return 0;
}

// run
