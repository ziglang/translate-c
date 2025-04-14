#include <stdlib.h>
#include <stdbool.h>
bool foo() { return true; }
int main() {
    int x = foo();
    if (x != 1) abort();
    signed char c = foo();
    if (c != 1) abort();
    return 0;
}

// run
