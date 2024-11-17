#define _NO_CRT_STDIO_INLINE 1
#include <stdio.h>
#define PI 3.14159265358979323846f
#define DEG2RAD (PI/180.0f)
int main(void) {
    printf("DEG2RAD is: %f", DEG2RAD);
    return 0;
}

// run
// expect=fail
//
// DEG2RAD is: 0.017453
