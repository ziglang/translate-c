int foo(void) {
    int v1;
    _Bool b1 = v1;
    double v2;
    _Bool b2 = v2;
    void* v3;
    _Bool b3 = v3;

    int v4 = b1;
    double v5 = b2;
    void* v6 = b3;
}

// translate
//
// pub export fn foo() c_int {
//     var v1: c_int = undefined;
//     _ = &v1;
//     var b1: bool = v1 != 0;
//     _ = &b1;
//     var v2: f64 = undefined;
//     _ = &v2;
//     var b2: bool = v2 != 0;
//     _ = &b2;
//     var v3: ?*anyopaque = undefined;
//     _ = &v3;
//     var b3: bool = v3 != null;
//     _ = &b3;
//     var v4: c_int = @intFromBool(b1);
//     _ = &v4;
//     var v5: f64 = @floatFromInt(@intFromBool(b2));
//     _ = &v5;
//     var v6: ?*anyopaque = @ptrFromInt(@intFromBool(b3));
//     _ = &v6;
//     return undefined;
// }
