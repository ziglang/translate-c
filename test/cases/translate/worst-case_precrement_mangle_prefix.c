void foo() {
    int n, ref = 1;
    if (n = ++ref) {}
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var n: c_int = undefined;
//     _ = &n;
//     var ref: c_int = 1;
//     _ = &ref;
//     if ((blk: {
//         const tmp = blk_1: {
//             const ref_2 = &ref;
//             ref_2.* += 1;
//             break :blk_1 ref_2.*;
//         };
//         n = tmp;
//         break :blk tmp;
//     }) != 0) {}
// }
