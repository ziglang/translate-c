#include <stdlib.h>
int _ = 10;
typedef struct { int _; } S;
int main(void) {
    if (_ != 10) abort();
    S foo = { ._ = _ };
    if (foo._ != _) abort();
    return 0;
}

// run
// expect=fail
