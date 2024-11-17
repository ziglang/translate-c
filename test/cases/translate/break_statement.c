void foo(void) {
    for (;;) {
        break;
    }
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     while (true) {
//         break;
//     }
// }
