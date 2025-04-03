void foo(void) {
    for (int i = 0; i; i++) { }
}

// translate
//
// pub export fn foo() void {
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i != 0) : (i += 1) {}
//     }
// }
