#include <stdlib.h>
int func(int val) {
    static int foo;
    if (foo != val) abort();
    {
        foo += 1;
        static int foo = 2;
        if (foo != val + 2) abort();
        foo += 1;
    }
    return foo;
}
int main(void) {
    int foo = 1;
    if (func(0) != 1) abort();
    if (func(1) != 2) abort();
    if (func(2) != 3) abort();
    if (foo != 1) abort();
    return 0;
}

// run
