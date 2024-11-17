#include <stdlib.h>
struct Foo {
    int a;
    char b[2];
    float c;
};
int main() {
    struct Foo foo;
    int x = 1, y = 2;
    foo = (struct Foo) {x + y, {'a', 'b'}, 42.0f};
    if (foo.a != x + y || foo.b[0] != 'a' || foo.b[1] != 'b' || foo.c != 42.0f) abort();
    return 0;
}

// run
// expect=fail
