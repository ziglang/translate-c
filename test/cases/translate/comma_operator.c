int foo() {
    2, 4;
    return 2, 4, 6;
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     _ = blk: {
//         _ = @as(c_int, 2);
//         break :blk @as(c_int, 4);
//     };
//     return blk: {
//         _ = blk_1: {
//             _ = @as(c_int, 2);
//             break :blk_1 @as(c_int, 4);
//         };
//         break :blk @as(c_int, 6);
//     };
// }
