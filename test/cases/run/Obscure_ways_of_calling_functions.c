#include <stdlib.h>
static int add(int a, int b) {
    return a + b;
}
typedef int (*adder)(int, int);
typedef void (*funcptr)(void);
int main() {
    if ((add)(1, 2) != 3) abort();
    if ((&add)(1, 2) != 3) abort();
    if (add(3, 1) != 4) abort();
    if ((*add)(2, 3) != 5) abort();
    if ((**add)(7, -1) != 6) abort();
    if ((***add)(-2, 9) != 7) abort();

    int (*ptr)(int a, int b);
    ptr = add;

    if (ptr(1, 2) != 3) abort();
    if ((*ptr)(3, 1) != 4) abort();
    if ((**ptr)(2, 3) != 5) abort();
    if ((***ptr)(7, -1) != 6) abort();
    if ((****ptr)(-2, 9) != 7) abort();

    funcptr addr1 = (funcptr)(add);
    funcptr addr2 = (funcptr)(&add);

    if (addr1 != addr2) abort();
    if (((int(*)(int, int))addr1)(1, 2) != 3) abort();
    if (((adder)addr2)(1, 2) != 3) abort();
    return 0;
}

// run
// expect=fail
