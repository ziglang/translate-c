int foo() {
    return 5;
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     return 5;
// }
