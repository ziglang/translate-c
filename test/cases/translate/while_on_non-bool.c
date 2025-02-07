int while_none_bool() {
    int a;
    float b;
    void *c;
    while (a) return 0;
    while (b) return 1;
    while (c) return 2;
    return 3;
}

// translate
//
// pub export fn while_none_bool() c_int {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: f32 = undefined;
//     _ = &b;
//     var c: ?*anyopaque = undefined;
//     _ = &c;
//     while (a != 0) return 0;
//     while (b != 0) return 1;
//     while (c != null) return 2;
//     return 3;
// }
