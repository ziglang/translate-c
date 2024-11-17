#include <stdlib.h>
#define FOO(x, y) (__builtin_popcount((x)) + __builtin_strlen((y)))
int main() {
    if (FOO(7, "hello!") != 9) abort();
    return 0;
}

// run
// expect=fail
