void foo(void) {
    int a = 2;
    do {
        a = a - 1;
    } while (a);

    int b = 2;
    do
        b = b -1;
    while (b);
    do {
        __builtin_unreachable();
    } while (0);
    do {
        continue;
    } while (1);
}

// translate
//
// pub export fn foo() void {
//     var a: c_int = 2;
//     _ = &a;
//     while (true) {
//         a = a - @as(c_int, 1);
//         if (!(a != 0)) break;
//     }
//     var b: c_int = 2;
//     _ = &b;
//     while (true) {
//         b = b - @as(c_int, 1);
//         if (!(b != 0)) break;
//     }
//     while (true) {
//         unreachable;
//     }
//     while (true) {
//         continue;
//     }
// }
