int foo() {}
int bar() {
    int a = 2;
}
int baz() {
    return 0;
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     return 0;
// }
// pub export fn bar() c_int {
//     var a: c_int = 2;
//     _ = &a;
//     return 0;
// }
// pub export fn baz() c_int {
//     return 0;
// }