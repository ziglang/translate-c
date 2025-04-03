void foo() {
    for (int i = 2, b = 4; i + 2; i = 2) {
        int a = 2;
        a = 6, 5, 7;
    }
    char i = 2;
}

// translate
//
// pub export fn foo() void {
//     {
//         var i: c_int = 2;
//         _ = &i;
//         var b: c_int = 4;
//         _ = &b;
//         while ((i + @as(c_int, 2)) != 0) : (i = 2) {
//             var a: c_int = 2;
//             _ = &a;
//             a = 6;
//             _ = 5;
//             _ = 7;
//         }
//     }
//     var i: u8 = 2;
//     _ = &i;
// }
