int foo(void) {
    return (1 << 2) >> 1;
}

// translate
//
// pub export fn foo() c_int {
//     return (@as(c_int, 1) << @intCast(2)) >> @intCast(1);
// }
