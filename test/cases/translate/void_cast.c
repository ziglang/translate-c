void foo() {
    int a;
    (void) a;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     _ = &a;
// }
