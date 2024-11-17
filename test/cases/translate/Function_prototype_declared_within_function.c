int foo(void) {
    extern int bar(int, int);
    return bar(1, 2);
}

// translate
// expect=fail
//
// pub extern fn bar(c_int, c_int) c_int;
// pub export fn foo() c_int {
//     return bar(@as(c_int, 1), @as(c_int, 2));
// }
