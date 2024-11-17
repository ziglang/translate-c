#include <stdlib.h>
typedef struct {
    char field;
} a_t, b_t;

int main(void) {
    a_t a = { .field = 42 };
    b_t b = a;
    if (b.field != 42) abort();
    return 0;
}

// run
// expect=fail
