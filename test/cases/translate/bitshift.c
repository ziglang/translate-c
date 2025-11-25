int foo(void) {
    return (1 << 2) >> 1;
}

// translate
//
// pub export fn foo() c_int {
//     return (@as(c_int, 1) << @intCast(@as(c_int, 2))) >> @intCast(@as(c_int, 1));
// }
