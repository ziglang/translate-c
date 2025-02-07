int foo(void) {
    return __extension__ 1;
}

// translate
//
// pub export fn foo() c_int {
//     return 1;
// }
