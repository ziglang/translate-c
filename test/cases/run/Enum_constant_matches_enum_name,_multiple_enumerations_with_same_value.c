#include <stdlib.h>
enum FOO {
    FOO = 1,
    BAR = 2,
    BAZ = 1,
};
int main(void) {
    enum FOO x = BAZ;
    if (x != 1) abort();
    if (x != BAZ) abort();
    if (x != FOO) abort();
}

// run
