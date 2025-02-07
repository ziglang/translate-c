int s() {
    int a, b, c;
    c = a + b;
    c = a - b;
    c = a * b;
    c = a / b;
    c = a % b;
}
unsigned u() {
    unsigned a, b, c;
    c = a + b;
    c = a - b;
    c = a * b;
    c = a / b;
    c = a % b;
}

// translate
// expect=fail
//
// pub export fn s() c_int {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: c_int = undefined;
//     _ = &b;
//     var c: c_int = undefined;
//     _ = &c;
//     c = a + b;
//     c = a - b;
//     c = a * b;
//     c = @divTrunc(a, b);
//     c = @import("std").zig.c_translation.signedRemainder(a, b);
//     return undefined;
// }
// pub export fn u() c_uint {
//     var a: c_uint = undefined;
//     _ = &a;
//     var b: c_uint = undefined;
//     _ = &b;
//     var c: c_uint = undefined;
//     _ = &c;
//     c = a +% b;
//     c = a -% b;
//     c = a *% b;
//     c = a / b;
//     c = a % b;
//     return undefined;
// }
