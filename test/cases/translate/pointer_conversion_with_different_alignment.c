void test_ptr_cast() {
    void *p;
    {
        char *to_char = (char *)p;
        short *to_short = (short *)p;
        int *to_int = (int *)p;
        long long *to_longlong = (long long *)p;
    }
    {
        char *to_char = p;
        short *to_short = p;
        int *to_int = p;
        long long *to_longlong = p;
    }
}

// translate
// expect=fail
//
// pub export fn test_ptr_cast() void {
//     var p: ?*anyopaque = undefined;
//     _ = &p;
//     {
//         var to_char: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(p)));
//         _ = &to_char;
//         var to_short: [*c]c_short = @as([*c]c_short, @ptrCast(@alignCast(p)));
//         _ = &to_short;
//         var to_int: [*c]c_int = @as([*c]c_int, @ptrCast(@alignCast(p)));
//         _ = &to_int;
//         var to_longlong: [*c]c_longlong = @as([*c]c_longlong, @ptrCast(@alignCast(p)));
//         _ = &to_longlong;
//     }
//     {
//         var to_char: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(p)));
//         _ = &to_char;
//         var to_short: [*c]c_short = @as([*c]c_short, @ptrCast(@alignCast(p)));
//         _ = &to_short;
//         var to_int: [*c]c_int = @as([*c]c_int, @ptrCast(@alignCast(p)));
//         _ = &to_int;
//         var to_longlong: [*c]c_longlong = @as([*c]c_longlong, @ptrCast(@alignCast(p)));
//         _ = &to_longlong;
//     }
// }
