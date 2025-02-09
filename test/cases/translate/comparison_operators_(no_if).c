int test_comparisons(int a, int b) {
    int c = (a < b);
    int d = (a > b);
    int e = (a <= b);
    int f = (a >= b);
    int g = (c < d);
    int h = (e < f);
    int i = (g < h);
    return i;
}

// translate
//
// pub export fn test_comparisons(arg_a: c_int, arg_b: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     var c: c_int = @intFromBool(a < b);
//     _ = &c;
//     var d: c_int = @intFromBool(a > b);
//     _ = &d;
//     var e: c_int = @intFromBool(a <= b);
//     _ = &e;
//     var f: c_int = @intFromBool(a >= b);
//     _ = &f;
//     var g: c_int = @intFromBool(c < d);
//     _ = &g;
//     var h: c_int = @intFromBool(e < f);
//     _ = &h;
//     var i: c_int = @intFromBool(g < h);
//     _ = &i;
//     return i;
// }
