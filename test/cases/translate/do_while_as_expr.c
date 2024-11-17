static void foo(void) {
    if (1)
        do {} while (0);
}

// translate
// expect=fail
//
// pub fn foo() callconv(.c) void {
//     if (true) while (true) {
//         if (!false) break;
//     };
// }
