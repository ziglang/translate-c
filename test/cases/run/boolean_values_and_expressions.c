#include <stdlib.h>
static const _Bool false_val = 0;
static const _Bool true_val = 1;
void foo(int x, int y) {
    _Bool r = x < y;
    if (!r) abort();
    _Bool self = foo;
    if (self == false_val) abort();
    if (((r) ? 'a' : 'b') != 'a') abort();
}
int main(int argc, char **argv) {
    foo(2, 5);
    if (false_val == true_val) abort();
    return 0;
}

// run
// expect=fail
