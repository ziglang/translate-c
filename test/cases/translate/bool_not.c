int foo() {
    int a;
    float b;
    void *c;
    return !(a == 0);
    return !a;
    return !b;
    return !c;
}

// translate
//
// pub export fn foo() c_int {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: f32 = undefined;
//     _ = &b;
//     var c: ?*anyopaque = undefined;
//     _ = &c;
//     return @intFromBool(!(a == @as(c_int, 0)));
//     return @intFromBool(!(a != 0));
//     return @intFromBool(!(b != 0));
//     return @intFromBool(!(c != null));
// }
