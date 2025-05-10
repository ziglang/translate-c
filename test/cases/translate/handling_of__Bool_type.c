_Bool foo(_Bool x) {
    _Bool a = x != 1;
    _Bool b = a != 0;
    _Bool c = foo;
    return foo(c != b);
}

// translate
//
// pub export fn foo(arg_x: bool) bool {
//     var x = arg_x;
//     _ = &x;
//     var a: bool = @as(c_int, @intFromBool(x)) != @as(c_int, 1);
//     _ = &a;
//     var b: bool = @as(c_int, @intFromBool(a)) != @as(c_int, 0);
//     _ = &b;
//     var c: bool = @intFromPtr(&foo) != 0;
//     _ = &c;
//     return foo(@as(c_int, @intFromBool(c)) != @as(c_int, @intFromBool(b)));
// }
