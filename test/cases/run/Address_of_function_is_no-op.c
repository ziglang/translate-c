#include <stdlib.h>
#include <stdbool.h>
typedef int (*myfunc)(int);
int a(int arg) { return arg + 1;}
int b(int arg) { return arg + 2;}
int caller(myfunc fn, int arg) {
    return fn(arg);
}
int main() {
    myfunc arr[3] = {&a, &b, a};
    myfunc foo = a;
    myfunc bar = &(a);
    if (foo != bar) abort();
    if (arr[0] == arr[1]) abort();
    if (arr[0] != arr[2]) abort();
    if (caller(b, 40) != 42) abort();
    if (caller(&b, 40) != 42) abort();
    return 0;
}

// run
