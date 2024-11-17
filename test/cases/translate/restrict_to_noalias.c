void foo(void *restrict bar, void *restrict);

// translate
// expect=fail
//
// pub extern fn foo(noalias bar: ?*anyopaque, noalias ?*anyopaque) void;
