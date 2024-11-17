float *ptrcast() {
    int *a;
    return (float *)a;
}

// translate
// expect=fail
//
// pub export fn ptrcast() [*c]f32 {
//     var a: [*c]c_int = undefined;
//     _ = &a;
//     return @as([*c]f32, @ptrCast(@alignCast(a)));
// }
