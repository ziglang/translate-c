// See __builtin_alloca_with_align comment in lib/c_builtins.zig
#include <stdlib.h>
void unused() {
    __builtin_alloca_with_align(1, 8);
}
int main(void) {
    if (__builtin_sqrt(1.0) != 1.0) abort();
    return 0;
}

// run
