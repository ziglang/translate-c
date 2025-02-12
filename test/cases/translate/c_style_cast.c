int int_from_float(float a) {
    return (int)a;
}

int add_int_from_float(float a, float b) {
    return (int)a + (int) b;
}

// translate
//
// pub export fn int_from_float(arg_a: f32) c_int {
//     var a = arg_a;
//     _ = &a;
//     return @intFromFloat(a);
// }
// pub export fn add_int_from_float(arg_a: f32, arg_b: f32) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     return @as(c_int, @intFromFloat(a)) + @as(c_int, @intFromFloat(b));
// }
