unsigned foo1(unsigned a) {
    a++;
    return a;
}
int foo2(int a) {
    a++;
    return a;
}
int *foo3(int *a) {
    a++;
    return a;
}

// translate
// expect=fail
//
// pub export fn foo1(arg_a: c_uint) c_uint {
//     var a = arg_a;
//     _ = &a;
//     a +%= 1;
//     return a;
// }
// pub export fn foo2(arg_a: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     a += 1;
//     return a;
// }
// pub export fn foo3(arg_a: [*c]c_int) [*c]c_int {
//     var a = arg_a;
//     _ = &a;
//     a += 1;
//     return a;
// }
