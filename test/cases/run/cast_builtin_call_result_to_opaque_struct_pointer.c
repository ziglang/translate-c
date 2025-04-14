#include <stdlib.h>
struct foo* make_foo(void)
{
    return (struct foo*)__builtin_strlen("0123456789ABCDEF");
}
int main(void) {
    struct foo *foo_pointer = make_foo();
    if (foo_pointer != (struct foo*)16) abort();
    return 0;
}

// run
