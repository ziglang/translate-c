__attribute__((always_inline)) int foo() {
    return 5;
}

// translate
//
// pub inline fn foo() c_int {
//     return 5;
// }
