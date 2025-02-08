void foo() {
    int tmp, n = 1;
    if (tmp = n) {}
}

// translate
//
// pub export fn foo() void {
//     var tmp: c_int = undefined;
//     _ = &tmp;
//     var n: c_int = 1;
//     _ = &n;
//     if ((blk: {
//         const tmp_1 = n;
//         tmp = tmp_1;
//         break :blk tmp_1;
//     }) != 0) {}
// }
