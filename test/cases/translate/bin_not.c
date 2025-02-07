int foo() {
    int x;
    return ~x;
}

// translate
//
// pub export fn foo() c_int {
//     var x: c_int = undefined;
//     _ = &x;
//     return ~x;
// }
