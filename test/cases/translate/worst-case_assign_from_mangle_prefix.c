void foo() {
    int n, tmp = 1;
    if (n = tmp) {}
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var n: c_int = undefined;
//     _ = &n;
//     var tmp: c_int = 1;
//     _ = &tmp;
//     if ((blk: {
//         const tmp_1 = tmp;
//         n = tmp_1;
//         break :blk tmp_1;
//     }) != 0) {}
// }
