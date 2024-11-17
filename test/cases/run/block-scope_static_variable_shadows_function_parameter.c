#include <stdlib.h>
int func1(int foo) { return foo + 1; }
int func2(void) {
    static int foo = 5;
    return foo++;
}
int main(void) {
    if (func1(42) != 43) abort();
    if (func2() != 5) abort();
    if (func2() != 6) abort();
    return 0;
}

// run
// expect=fail
