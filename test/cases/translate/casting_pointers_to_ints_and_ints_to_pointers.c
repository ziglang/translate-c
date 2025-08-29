void foo(void) {
    int x = 23;
    int y = (int*)x;
}
void bar(void) {
    void *func_ptr = foo;
    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
}

// translate
//
// pub export fn foo() void {
//     var x: c_int = 23;
//     _ = &x;
//     var y: c_int = @intCast(@intFromPtr(@as([*c]c_int, @ptrFromInt(@as(usize, @intCast(x))))));
//     _ = &y;
// }
// pub export fn bar() void {
//     var func_ptr: ?*anyopaque = @ptrCast(@alignCast(@constCast(&foo)));
//     _ = &func_ptr;
//     var typed_func_ptr: ?*const fn () callconv(.c) void = @ptrFromInt(@as(c_ulong, @intCast(@intFromPtr(func_ptr))));
//     _ = &typed_func_ptr;
// }
