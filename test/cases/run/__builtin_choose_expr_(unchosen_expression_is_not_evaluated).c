#include <stdlib.h>
int main(void) {
    int x = 0.0;
    int y = 0.0;
    int res;
    res = __builtin_choose_expr(1, 1, x / y);
    if (res != 1) abort();
    res = __builtin_choose_expr(0, x / y, 2);
    if (res != 2) abort();
    return 0;
}

// run
