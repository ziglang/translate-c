// The C standard does not require function pointers to be convertible to any integer type.
// However, POSIX requires that function pointers have the same representation as `void *`
// so that dlsym() can work
#include <stdint.h>
int main(void) {
#if defined(__UINTPTR_MAX__) && __has_include(<unistd.h>)
    uintptr_t x = (uintptr_t)main;
#endif
    return 0;
}

// run
