#include <stdlib.h>
static void foo(struct foobar *unused) {}
int main(void) {
    int struct_foobar = 123;
    if (struct_foobar != 123) abort();
    int foobar = 456;
    if (foobar != 456) abort();
    return 0;
}

// run
// expect=fail
