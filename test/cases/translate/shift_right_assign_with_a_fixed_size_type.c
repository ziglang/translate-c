#include <stdint.h>
int log2(uint32_t a) {
    int i = 0;
    while (a > 0) {
        a >>= 1;
    }
    return i;
}

// translate
//
// pub export fn log2(arg_a: u32) c_int {
//     var a = arg_a;
//     _ = &a;
//     var i: c_int = 0;
//     _ = &i;
//     while (a > @as(u32, 0)) {
//         a >>= @intCast(1);
//     }
//     return i;
// }
