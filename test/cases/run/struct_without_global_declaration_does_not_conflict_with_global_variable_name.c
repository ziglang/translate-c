#include <stdlib.h>
static void foo(struct foobar *unused) {}
static int struct_foobar = 123;
static int foobar = 456;
int main(void) {
    if (struct_foobar != 123) abort();
    if (foobar != 456) abort();
    return 0;
}

// run
