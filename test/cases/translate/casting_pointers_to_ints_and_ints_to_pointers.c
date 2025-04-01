void foo(void);
void bar(void) {
    void *func_ptr = foo;// TODO missing const cast in result
    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
}

// translate
//
// pub extern fn foo() void;
// pub export fn bar() void {
//     var func_ptr: ?*anyopaque = foo;
//     _ = &func_ptr;
//     var typed_func_ptr: ?*const fn () callconv(.c) void = @ptrFromInt(@as(c_ulong, @intFromPtr(func_ptr)));
//     _ = &typed_func_ptr;
// }
