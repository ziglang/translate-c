#include <stdlib.h>
int main(void) {
    int foo[] = {1, 2, 3, 4};
    int *p = foo;
    int idx = 1;
    if ((++p)[--idx] != 2) abort();
    if (p != foo + 1) abort();
    if (idx != 0) abort();
    if ((p++)[idx++] != 2) abort();
    if (p != foo + 2) abort();
    if (idx != 1) abort();
    return 0;
}

// run
