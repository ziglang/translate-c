void foo(void) {
    for (;;) {
        continue;
    }
}

// translate
//
// pub export fn foo() void {
//     while (true) {
//         continue;
//     }
// }
