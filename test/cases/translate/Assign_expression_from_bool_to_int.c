void foo(void) {
    int a;
    if (a = 1 > 0) {}
}

// translate
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     if ((blk: {
//         const tmp = @intFromBool(@as(c_int, 1) > @as(c_int, 0));
//         a = tmp;
//         break :blk tmp;
//     }) != 0) {}
// }
