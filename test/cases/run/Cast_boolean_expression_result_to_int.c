#include <stdlib.h>
char foo(char c) { return c; }
int  bar(int i)  { return i; }
long baz(long l) { return l; }
int main() {
    if (foo(1 == 2)) abort();
    if (!foo(1 == 1)) abort();
    if (bar(1 == 2)) abort();
    if (!bar(1 == 1)) abort();
    if (baz(1 == 2)) abort();
    if (!baz(1 == 1)) abort();
    return 0;
}

// run
