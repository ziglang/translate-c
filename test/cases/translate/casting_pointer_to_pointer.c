float **ptrptrcast() {
    int **a;
    return (float **)a;
}

// translate
// expect=fail
//
// pub export fn ptrptrcast() [*c][*c]f32 {
//     var a: [*c][*c]c_int = undefined;
//     _ = &a;
//     return @as([*c][*c]f32, @ptrCast(@alignCast(a)));
// }
