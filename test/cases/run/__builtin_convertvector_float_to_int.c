#include <stdlib.h>
typedef int i32x2 __attribute__((__vector_size__(8)));
typedef float f32x2 __attribute__((__vector_size__(8)));
int main(int argc, char *argv[]) {
    f32x2 x = { 1.4, 2.4 };
    i32x2 a = __builtin_convertvector((f32x2){ x[0], x[1] }, i32x2);
    if (a[0] != 1) abort();
    if (a[1] != 2) abort();
    return 0;
}

// run
