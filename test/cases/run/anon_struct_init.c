#include <stdlib.h>
struct {int a; int b;} x = {1, 2};
int main(int argc, char **argv) {
    x.a += 2;
    x.b += 1;
    if (x.a != 3) abort();
    if (x.b != 3) abort();
    return 0;
}

// run
