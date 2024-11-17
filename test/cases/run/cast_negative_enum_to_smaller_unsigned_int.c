#include <stdlib.h>
#include <stdint.h>
typedef enum {
    ENUM_MINUS_1 = -1,
    ENUM_384 = 384,
} my_enum_t;

int main() {
    my_enum_t val = ENUM_MINUS_1;
    uint8_t x = (uint8_t)val;
    if (x != (uint8_t)-1) abort();
    return 0;
}

// run
// expect=fail
