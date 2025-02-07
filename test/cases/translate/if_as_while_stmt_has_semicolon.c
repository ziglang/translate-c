void foo() {
    while (1) if (1) {
        int a = 1;
    } else {
        int b = 2;
    }
    if (1) if (1) {}
}

// translate
//
// pub export fn foo() void {
//     while (true) if (true) {
//         var a: c_int = 1;
//         _ = &a;
//     } else {
//         var b: c_int = 2;
//         _ = &b;
//     };
//     if (true) if (true) {};
//     return;
// }
