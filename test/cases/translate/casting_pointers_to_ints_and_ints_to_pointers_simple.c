void foo(void) {
    int x = 23;
    int y = (int*)y;
}

// translate
//
// pub export fn foo() void {
//     var x: c_int = 23;
//     _ = &x;
//     var y: c_int = @intCast(@intFromPtr(@as([*c]c_int, @ptrFromInt(y))));
//     _ = &y;
// }
