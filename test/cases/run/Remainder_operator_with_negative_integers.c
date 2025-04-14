#include <stdlib.h>
int main(void) {
    int denominator = -2;
    int numerator = 5;
    if (numerator % denominator != 1) abort();
    numerator = -5; denominator = 2;
    if (numerator % denominator != -1) abort();
    return 0;
}

// run
