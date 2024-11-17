#include <stdlib.h>
#include <stdio.h>
int main(void) {
    if (1 || (abort(), 1)) {}
    if (0 && (1, printf("do not print\n"))) {}
    int x = 0;
    x = (x = 3, 4, x + 1);
    if (x != 4) abort();
    return 0;
}

// run
// expect=fail
