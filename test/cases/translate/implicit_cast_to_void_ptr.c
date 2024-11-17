void *foo() {
    unsigned short *x;
    return x;
}

// translate
// expect=fail
//
// pub export fn foo() ?*anyopaque {
//     var x: [*c]c_ushort = undefined;
//     _ = &x;
//     return @as(?*anyopaque, @ptrCast(x));
// }
