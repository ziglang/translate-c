#include <stdint.h>
#include <stdlib.h>
enum Foo { A, B, C };
static inline enum Foo do_stuff(void) {
    int64_t i = 1;
    return (enum Foo)i;
}
int main(void) {
    if (do_stuff() != B) abort();
    return 0;
}

// run
