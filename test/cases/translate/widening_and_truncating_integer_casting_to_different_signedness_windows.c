unsigned long foo(void) {
    return -1;
}
unsigned short bar(long x) {
    return x;
}

// translate
// target=native-windows-msvc
//
// pub export fn foo() c_ulong {
//     return 4294967295;
// }
// pub export fn bar(arg_x: c_long) c_ushort {
//     var x = arg_x;
//     _ = &x;
//     return @bitCast(@as(c_short, @truncate(x)));
// }
