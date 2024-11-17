#include <stdlib.h>
#define $FOO 2
#define $foo bar$
#define $baz($x) ($x + $FOO)
int $$$(int $x$) { return $x$ + $FOO; }
int main() {
    int bar$ = 42;
    if ($foo != 42) abort();
    if (bar$ != 42) abort();
    if ($baz(bar$) != 44) abort();
    if ($$$(bar$) != 44) abort();
    return 0;
}

// run
// expect=fail
