enum SomeEnum { A, B, C };
int if_none_bool(int a, float b, void *c, enum SomeEnum d) {
    if (a) return 0;
    if (b) return 1;
    if (c) return 2;
    if (d) return 3;
    return 4;
}

// translate
// expect=fail
// target=native-linux
//
// pub const A: c_int = 0;
// pub const B: c_int = 1;
// pub const C: c_int = 2;
// pub const enum_SomeEnum = c_uint;
// pub export fn if_none_bool(arg_a: c_int, arg_b: f32, arg_c: ?*anyopaque, arg_d: enum_SomeEnum) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     var c = arg_c;
//     _ = &c;
//     var d = arg_d;
//     _ = &d;
//     if (a != 0) return 0;
//     if (b != 0) return 1;
//     if (c != null) return 2;
//     if (d != 0) return 3;
//     return 4;
// }
