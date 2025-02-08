void foo(int a) {
    do {
        if (a) break;
    } while (4);
    do {
        if (a) break;
    } while (0);
    do {
        if (a) break;
    } while (a);
    do {
        break;
    } while (3);
    do {
        break;
    } while (0);
    do {
        break;
    } while (a);
}

// translate
//
// pub export fn foo(arg_a: c_int) void {
//     var a = arg_a;
//     _ = &a;
//     while (true) {
//         if (a != 0) break;
//     }
//     while (true) {
//         if (a != 0) break;
//         if (!false) break;
//     }
//     while (true) {
//         if (a != 0) break;
//         if (!(a != 0)) break;
//     }
//     while (true) {
//         break;
//     }
//     while (true) {
//         break;
//     }
//     while (true) {
//         break;
//     }
// }
