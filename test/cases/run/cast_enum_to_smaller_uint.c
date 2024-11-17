#include <stdlib.h>
#include <stdint.h>
typedef enum {
    ENUM_0 = 0,
    ENUM_257 = 257,
} my_enum_t;

int main() {
    my_enum_t val = ENUM_257;
    uint8_t x = (uint8_t)val;
    if (x != (uint8_t)257) abort();
    return 0;
}

// run
// expect=fail
