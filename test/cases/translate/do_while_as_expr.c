static void foo(void) {
    if (1)
        do {} while (0);
}

// translate
//
// pub fn foo() callconv(.c) void {
//     if (true) while (true) {
//         if (!false) break;
//     };
// }
