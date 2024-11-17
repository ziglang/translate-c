void foo() {
    int *x;
    *x = 1;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var x: [*c]c_int = undefined;
//     _ = &x;
//     x.* = 1;
// }
