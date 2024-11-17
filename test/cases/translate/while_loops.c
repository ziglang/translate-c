int foo() {
    int a = 5;
    while (2)
        a = 2;
    while (4) {
        int a = 4;
        a = 9;
        return 6, a;
    }
    do {
        int a = 2;
        a = 12;
    } while (4);
    do
        a = 7;
    while (4);
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     var a: c_int = 5;
//     _ = &a;
//     while (true) {
//         a = 2;
//     }
//     while (true) {
//         var a_1: c_int = 4;
//         _ = &a_1;
//         a_1 = 9;
//         return blk: {
//             _ = @as(c_int, 6);
//             break :blk a_1;
//         };
//     }
//     while (true) {
//         var a_1: c_int = 2;
//         _ = &a_1;
//         a_1 = 12;
//     }
//     while (true) {
//         a = 7;
//     }
//     return 0;
// }
