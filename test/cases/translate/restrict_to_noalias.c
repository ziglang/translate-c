void foo(void *restrict bar, void *restrict);

// translate
//
// pub extern fn foo(noalias bar: ?*anyopaque, noalias ?*anyopaque) void;
