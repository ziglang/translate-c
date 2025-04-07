void foo(int *p) {
    p[0];
    p[1];
}

// translate
//
// pub export fn foo(arg_p: [*c]c_int) void {
//     var p = arg_p;
//     _ = &p;
//     _ = p[@as(c_int, 0)];
//     _ = p[@as(c_int, 1)];
// }
