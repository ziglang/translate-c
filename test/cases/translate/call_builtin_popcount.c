int max(int a) {
    return __builtin_popcount(1);
}

// translate
//
// pub const __builtin = @import("c_builtins");
//
// pub export fn max(arg_a: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     return __builtin.popcount(1);
// }
