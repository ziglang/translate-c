int foo() {
    int a;
    float b;
    void *c;
    if (1) return !(a == 0);
    if (1) return !a;
    if (1) return !b;
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
//     if (true) return @intFromBool(!(a == @as(c_int, 0)));
//     if (true) return @intFromBool(!(a != 0));
//     if (true) return @intFromBool(!(b != 0));
//     return @intFromBool(!(c != null));
// }
