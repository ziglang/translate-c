#include <stddef.h>
size_t size_of(void) {
        return sizeof(int);
}
size_t size_of_expr(void) {
        return sizeof 1;
}
#define sizeof_macro(x) sizeof(x)

// translate
//
// pub export fn size_of() usize {
//     return @sizeOf(c_int);
// }
//
// pub export fn size_of_expr() usize {
//     return @sizeOf(@TypeOf(@as(c_int, 1)));
// }
//
// pub inline fn sizeof_macro(x: anytype) @TypeOf(__helpers.sizeof(x)) {
//     _ = &x;
//     return __helpers.sizeof(x);
// }
