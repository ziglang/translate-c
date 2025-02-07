int max(int a) {
    return __builtin_popcount(1);
}

// translate
//
// pub inline fn __builtin_popcount(val: c_uint) c_int {
//     @setRuntimeSafety(false);
//     return @as(c_int, @bitCast(@as(c_uint, @popCount(val))));
// }
// pub export fn max(arg_a: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     return __builtin_popcount(1);
// }
