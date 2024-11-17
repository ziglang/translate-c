void foo(void (__cdecl *fn_ptr)(void));

// translate
// expect=fail
//
// pub extern fn foo(fn_ptr: ?*const fn () callconv(.c) void) void;
