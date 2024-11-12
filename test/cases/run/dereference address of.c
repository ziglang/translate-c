#include <stdlib.h>
int main(void) {
    int i = 0;
    *&i = 42;
    if (i != 42) abort();
    return 0;
}

// run
// expect=fail
