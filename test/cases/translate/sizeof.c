#include <stddef.h>
size_t size_of(void) {
        return sizeof(int);
}

// translate
// expect=fail
//
// pub export fn size_of() usize {
//     return @sizeOf(c_int);
// }
