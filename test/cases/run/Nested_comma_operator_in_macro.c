#include <stdlib.h>
#define FOO (1, (2,  3))
int main(void) {
    int x = FOO;
    if (x != 3) abort();
    return 0;
}

// run
