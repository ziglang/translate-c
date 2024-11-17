__attribute__((always_inline)) int foo() {
    return 5;
}

// translate
// expect=fail
//
// pub inline fn foo() c_int {
//     return 5;
// }
