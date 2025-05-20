#include <stdlib.h>
typedef enum {
    ENUM_0 = 0,
    ENUM_1 = 1,
} my_enum_t;

int main() {
    my_enum_t val = ENUM_1;
    int x = val;
    if (x != 1) abort();
    return 0;
}

// run
