void foo(void) {
    for (;;) {
        break;
    }
}

// translate
//
// pub export fn foo() void {
//     while (true) {
//         break;
//     }
// }
