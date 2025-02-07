void foo() {
    int *x;
    *x = 1;
}

// translate
//
// pub export fn foo() void {
//     var x: [*c]c_int = undefined;
//     _ = &x;
//     x.* = 1;
// }
