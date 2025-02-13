void foo(void) {
    int i;
    for (i = 3; i; i--) { }
}

// translate
//
// pub export fn foo() void {
//     var i: c_int = undefined;
//     _ = &i;
//     {
//         i = 3;
//         while (i != 0) : (i -= 1) {}
//     }
// }
