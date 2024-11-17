void foo(void);
void bar(void) {
    void *func_ptr = foo;
    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
}

// translate
// expect=fail
//
// pub extern fn foo() void;
// pub export fn bar() void {
//     var func_ptr: ?*anyopaque = @as(?*anyopaque, @ptrCast(&foo));
//     _ = &func_ptr;
//     var typed_func_ptr: ?*const fn () callconv(.c) void = @as(?*const fn () callconv(.c) void, @ptrFromInt(@as(c_ulong, @intCast(@intFromPtr(func_ptr)))));
//     _ = &typed_func_ptr;
// }
