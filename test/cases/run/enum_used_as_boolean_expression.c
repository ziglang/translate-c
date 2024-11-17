#include <stdlib.h>
enum FOO {BAR, BAZ};
int main(void) {
    enum FOO x = BAR;
    if (x) abort();
    if (!BAZ) abort();
    return 0;
}

// run
// expect=fail
