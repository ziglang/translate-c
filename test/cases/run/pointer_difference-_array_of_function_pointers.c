#include <stdlib.h>
int a(void) { return 1;}
int b(void) { return 2;}
int c(void) { return 3;}
typedef int (*myfunc)(void);
int main() {
    myfunc arr[] = {a, b, c, a, b, c};
    myfunc *f1 = &arr[1];
    myfunc *f4 = &arr[4];
    if (f4 - f1 != 3) abort();
    return 0;
}

// run
// expect=fail
