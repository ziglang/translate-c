int log2(unsigned a) {
    int i = 0;
    while (a > 0) {
        a >>= 1;
    }
    return i;
}

// translate
// expect=fail
//
// pub export fn log2(arg_a: c_uint) c_int {
//     var a = arg_a;
//     _ = &a;
//     var i: c_int = 0;
//     _ = &i;
//     while (a > @as(c_uint, @bitCast(@as(c_int, 0)))) {
//         a >>= @intCast(@as(c_int, 1));
//     }
//     return i;
// }
