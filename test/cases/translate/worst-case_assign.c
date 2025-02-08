void foo() {
    int a;
    int b;
    a = b = 2;
}

// translate
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: c_int = undefined;
//     _ = &b;
//     a = blk: {
//         const tmp = 2;
//         b = tmp;
//         break :blk tmp;
//     };
// }
