#include <stdlib.h>
int foo() {
    static int bar;
    bar += 1;
    return bar;
}
int main() {
    foo();
    foo();
    if (foo() != 3) abort();
}

// run
// expect=fail
