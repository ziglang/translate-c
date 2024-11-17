void foo() {
    if (2) {
        int a = 2;
    }
    if (2, 5) {
        int a = 2;
    }
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     if (true) {
//         var a: c_int = 2;
//         _ = &a;
//     }
//     if ((blk: {
//         _ = @as(c_int, 2);
//         break :blk @as(c_int, 5);
//     }) != 0) {
//         var a: c_int = 2;
//         _ = &a;
//     }
// }
