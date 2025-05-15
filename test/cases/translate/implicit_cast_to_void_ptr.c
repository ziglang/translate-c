void *foo() {
    unsigned short *x;
    return x;
}

// translate
//
// pub export fn foo() ?*anyopaque {
//     var x: [*c]c_ushort = undefined;
//     _ = &x;
//     return @ptrCast(@alignCast(x));
// }
