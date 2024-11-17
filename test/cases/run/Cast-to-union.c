#include <stdlib.h>
struct S { int x; };
union U {
    long l;
    double d;
    struct S s;
};
union U bar(union U u) { return u; }
int main(void) {
    union U u = (union U) 42L;
    if (u.l != 42L) abort();
    u = (union U) 2.0;
    if (u.d != 2.0) abort();
    u = bar((union U)4.0);
    if (u.d != 4.0) abort();
    u = (union U)(struct S){ .x = 5 };
    if (u.s.x != 5) abort();
    return 0;
}

// run
// expect=fail
