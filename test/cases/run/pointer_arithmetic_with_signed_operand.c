#include <stdlib.h>
int main() {
    int array[10];
    int *x = &array[5];
    int *y;
    int idx = 0;
    y = x + ++idx;
    if (y != x + 1 || y != &array[6]) abort();
    y = idx + x;
    if (y != x + 1 || y != &array[6]) abort();
    y = x - idx;
    if (y != x - 1 || y != &array[4]) abort();

    idx = 0;
    y = --idx + x;
    if (y != x - 1 || y != &array[4]) abort();
    y = idx + x;
    if (y != x - 1 || y != &array[4]) abort();
    y = x - idx;
    if (y != x + 1 || y != &array[6]) abort();

    idx = 1;
    x += idx;
    if (x != &array[6]) abort();
    x -= idx;
    if (x != &array[5]) abort();
    y = (x += idx);
    if (y != x || y != &array[6]) abort();
    y = (x -= idx);
    if (y != x || y != &array[5]) abort();

    if (array + idx != &array[1] || array + 1 != &array[1]) abort();
    idx = -1;
    if (array - idx != &array[1]) abort();

    return 0;
}

// run
// expect=fail
