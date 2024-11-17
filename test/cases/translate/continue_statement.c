void foo(void) {
    for (;;) {
        continue;
    }
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     while (true) {
//         continue;
//     }
// }
