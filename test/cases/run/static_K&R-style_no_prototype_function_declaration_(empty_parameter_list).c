#include <stdlib.h>
static int foo() {
    return 42;
}
int main() {
    if (foo() != 42) abort();
    return 0;
}

// run
