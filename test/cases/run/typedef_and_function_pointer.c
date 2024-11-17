#include <stdlib.h>
typedef struct _Foo Foo;
typedef int Ret;
typedef int Param;
struct _Foo { Ret (*func)(Param p); };
static Ret add1(Param p) {
    return p + 1;
}
int main(int argc, char **argv) {
    Foo strct = { .func = add1 };
    if (strct.func(16) != 17) abort();
    return 0;
}

// run
// expect=fail
