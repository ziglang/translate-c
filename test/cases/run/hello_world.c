#define _NO_CRT_STDIO_INLINE 1
#include <stdio.h>
int main(int argc, char **argv) {
    printf("hello, world!");
    return 0;
}

// run
// expect=fail
//
// hello, world!
