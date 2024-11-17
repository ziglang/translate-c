int foo(void) {
    int x = 1234;
    int *ptr = &x;
    return *ptr;
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     var x: c_int = 1234;
//     _ = &x;
//     var ptr: [*c]c_int = &x;
//     _ = &ptr;
//     return ptr.*;
// }
