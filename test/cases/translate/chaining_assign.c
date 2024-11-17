void max(int a) {
    int b, c;
    c = b = a;
}

// translate
// expect=fail
//
// pub export fn max(arg_a: c_int) void {
//     var a = arg_a;
//     _ = &a;
//     var b: c_int = undefined;
//     _ = &b;
//     var c: c_int = undefined;
//     _ = &c;
//     c = blk: {
//         const tmp = a;
//         b = tmp;
//         break :blk tmp;
//     };
// }
