#include <stdlib.h>
int main() {
    int foo[10];
    int *x = &foo[1];
    const int *y = &foo[5];
    if (y - x++ != 4) abort();
    if (y - x != 3) abort();
    if (y - ++x != 2) abort();
    if (y - x-- != 2) abort();
    if (y - x != 3) abort();
    if (y - --x != 4) abort();
    if (y - &foo[0] != 5) abort();
    return 0;
}

// run
// expect=fail
