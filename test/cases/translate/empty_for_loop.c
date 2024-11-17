void foo(void) {
    for (;;) { }
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     while (true) {}
// }
