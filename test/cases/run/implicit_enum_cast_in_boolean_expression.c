#include <stdlib.h>
enum Foo {
    FooA,
    FooB,
    FooC,
};
int main() {
    int a = 0;
    float b = 0;
    void *c = 0;
    enum Foo d = FooA;
    if (a || d) abort();
    if (d && b) abort();
    if (c || d) abort();
    return 0;
}

// run
// expect=fail
