void foo() {
    int ref, n = 1;
    if (ref += n) {}
}

// translate
//
// pub export fn foo() void {
//     var ref: c_int = undefined;
//     _ = &ref;
//     var n: c_int = 1;
//     _ = &n;
//     if ((blk: {
//         const ref_1 = &ref;
//         ref_1.* += n;
//         break :blk ref_1.*;
//     }) != 0) {}
// }
