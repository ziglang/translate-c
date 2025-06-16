#include <stdlib.h>
static int foo();
static int foo(int a, int b) {
    return a + b;
}
int main() {
    if (foo(40, 2) != 42) abort();
    return 0;
}

// run
