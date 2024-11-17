#include <stdlib.h>
#include <stdint.h>
typedef enum {
    ENUM_0 = 0,
    ENUM_384 = 384,
} my_enum_t;

int main() {
    my_enum_t val = ENUM_384;
    int8_t x = (int8_t)val;
    if (x != (int8_t)384) abort();
    return 0;
}

// run
// expect=fail
