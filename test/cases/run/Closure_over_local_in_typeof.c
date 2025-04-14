#include <stdlib.h>
int main(void) {
    int x = 123;
    union { typeof(x) val; } u = { x };
    if (u.val != 123) abort();
    return 0;
}

// run
