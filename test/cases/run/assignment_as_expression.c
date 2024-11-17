#include <stdlib.h>
int main() {
    int a, b, c, d = 5;
    int e = a = b = c = d;
    if (e != 5) abort();
}

// run
// expect=fail
