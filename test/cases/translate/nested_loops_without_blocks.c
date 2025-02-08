void foo() {
    while (0) while (0) {}
    for (;;) while (0);
    for (;;) do {} while (0);
}

// translate
//
// pub export fn foo() void {
//     while (false) while (false) {};
//     while (true) while (false) {};
//     while (true) while (true) {
//         if (!false) break;
//     };
// }
