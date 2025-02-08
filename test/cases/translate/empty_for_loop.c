void foo(void) {
    for (;;) { }
}

// translate
//
// pub export fn foo() void {
//     while (true) {}
// }
