unsigned long foo(void) {
    return -1;
}
unsigned short bar(long x) {
    return x;
}

// translate
// expect=fail
//
// pub export fn foo() c_ulong {
//     return @as(c_ulong, @bitCast(@as(c_long, -@as(c_int, 1))));
// }
// pub export fn bar(arg_x: c_long) c_ushort {
//     var x = arg_x;
//     _ = &x;
//     return @as(c_ushort, @bitCast(@as(c_short, @truncate(x))));
// }
