unsigned long foo(void) {
    return -1;
}
unsigned short bar(long x) {
    return x;
}

// translate
//
// pub export fn foo() c_ulong {
//     return @bitCast(@as(c_long, -@as(c_int, 1)));
// }
// pub export fn bar(arg_x: c_long) c_ushort {
//     var x = arg_x;
//     _ = &x;
//     return @bitCast(@as(c_short, @truncate(x)));
// }
