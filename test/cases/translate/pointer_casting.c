float *ptrcast() {
    int *a;
    return (float *)a;
}

// translate
//
// pub export fn ptrcast() [*c]f32 {
//     var a: [*c]c_int = undefined;
//     _ = &a;
//     return @ptrCast(@alignCast(a));
// }
