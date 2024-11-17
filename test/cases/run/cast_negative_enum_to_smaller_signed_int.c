#include <stdlib.h>
#include <stdint.h>
typedef enum {
    ENUM_MINUS_1 = -1,
    ENUM_384 = 384,
} my_enum_t;

int main() {
    my_enum_t val = ENUM_MINUS_1;
    int8_t x = (int8_t)val;
    if (x != -1) abort();
    return 0;
}

// run
// expect=fail
