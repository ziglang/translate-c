int foo() {
    2, 4;
    return 2, 4, 6;
}

// translate
//
// pub export fn foo() c_int {
//     _ = 2;
//     _ = 4;
//     return blk: {
//         _ = 2;
//         _ = 4;
//         break :blk 6;
//     };
// }
