float **ptrptrcast() {
    int **a;
    return (float **)a;
}

// translate
//
// pub export fn ptrptrcast() [*c][*c]f32 {
//     var a: [*c][*c]c_int = undefined;
//     _ = &a;
//     return @ptrCast(@alignCast(a));
// }
