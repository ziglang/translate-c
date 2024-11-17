#define _NO_CRT_STDIO_INLINE 1
#include <stdio.h>
int main(void) {
    printf("%d %d", 1, 2);
    return 0;
}

// run
// expect=fail
//
// 1 2
