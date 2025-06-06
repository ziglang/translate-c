#include <stdlib.h>
int foo(int);
int foo(int x) { return x + 1; }
int main(int argc, char **argv) {
    if (foo(2) != 3) abort();
    return 0;
}

// run
