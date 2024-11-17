void foo() {
    int cond_temp = 1;
    int n, f = 1;
    if (n = (f)?:(cond_temp)) {}
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var cond_temp: c_int = 1;
//     _ = &cond_temp;
//     var n: c_int = undefined;
//     _ = &n;
//     var f: c_int = 1;
//     _ = &f;
//     if ((blk: {
//         const tmp = blk_1: {
//             const cond_temp_2 = f;
//             break :blk_1 if (cond_temp_2 != 0) cond_temp_2 else cond_temp;
//         };
//         n = tmp;
//         break :blk tmp;
//     }) != 0) {}
// }
