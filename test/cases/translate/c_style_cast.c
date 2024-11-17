int int_from_float(float a) {
    return (int)a;
}

// translate
// expect=fail
//
// pub export fn int_from_float(arg_a: f32) c_int {
//     var a = arg_a;
//     _ = &a;
//     return @as(c_int, @intFromFloat(a));
// }
