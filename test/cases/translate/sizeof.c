#include <stddef.h>
size_t size_of(void) {
        return sizeof(int);
}
size_t size_of_expr(void) {
        return sizeof 1;
}

// translate
//
// pub export fn size_of() usize {
//     return @sizeOf(c_int);
// }
//
// pub export fn size_of_expr() usize {
//     return @sizeOf(@TypeOf(@as(c_int, 1)));
// }

