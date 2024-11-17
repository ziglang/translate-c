#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define my_generic_fn(X) _Generic((X),    \
              int: abs,                   \
              char *: strlen,             \
              size_t: malloc,             \
              default: free               \
)(X)
#define my_generic_val(X) _Generic((X),   \
              int: 1,                     \
              const char *: "bar"         \
)
int main(void) {
    if (my_generic_val(100) != 1) abort();

    const char *foo = "foo";
    const char *bar = my_generic_val(foo);
    if (strcmp(bar, "bar") != 0) abort();

    if (my_generic_fn(-42) != 42) abort();
    if (my_generic_fn("hello") != 5) abort();

    size_t size = 8192;
    uint8_t *mem = my_generic_fn(size);
    memset(mem, 42, size);
    if (mem[size - 1] != 42) abort();
    my_generic_fn(mem);

    return 0;
}

// run
// expect=fail
