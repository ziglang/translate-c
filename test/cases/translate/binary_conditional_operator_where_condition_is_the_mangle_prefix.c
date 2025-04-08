void foo() {
    int f = 1;
    int n, cond_temp = 1;
    if (n = (cond_temp)?:(f)) {}
}

// translate
//
// pub export fn foo() void {
//     var f: c_int = 1;
//     _ = &f;
//     var n: c_int = undefined;
//     _ = &n;
//     var cond_temp: c_int = 1;
//     _ = &cond_temp;
//     if ((blk: {
//         const tmp = blk_1: {
//             const cond_temp_2 = cond_temp;
//             break :blk_1 if (cond_temp_2 != 0) cond_temp_2 else f;
//         };
//         n = tmp;
//         break :blk tmp;
//     }) != 0) {}
// }
