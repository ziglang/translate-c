int foo(void) {
    return __extension__ 1;
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     return 1;
// }
