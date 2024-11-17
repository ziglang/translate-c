int abs(int a) {
    return a < 0 ? -a : a;
}

// translate
// expect=fail
//
// pub export fn abs(arg_a: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     return if (a < @as(c_int, 0)) -a else a;
// }
