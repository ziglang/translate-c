void foo(void) {
    return;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     return;
// }
