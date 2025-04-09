void foo() {
    int n, ref = 1;
    if (n += ref) {}
}

// translate
//
// pub export fn foo() void {
//     var n: c_int = undefined;
//     _ = &n;
//     var ref: c_int = 1;
//     _ = &ref;
//     if ((blk: {
//         const ref_1 = &n;
//         ref_1.* += ref;
//         break :blk ref_1.*;
//     }) != 0) {}
// }
