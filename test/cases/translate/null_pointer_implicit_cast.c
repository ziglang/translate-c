int* foo(void) {
    return 0;
}

// translate
// expect=fail
//
// pub export fn foo() [*c]c_int {
//     return null;
// }
