extern void (*fn_ptr)(void);
#define foo fn_ptr

extern char (*fn_ptr2)(int, float);
#define bar fn_ptr2

// translate
// expect=fail
//
// pub extern var fn_ptr: ?*const fn () callconv(.c) void;
//
// pub inline fn foo() void {
//     return fn_ptr.?();
// }
//
// pub extern var fn_ptr2: ?*const fn (c_int, f32) callconv(.c) u8;
//
// pub inline fn bar(arg_1: c_int, arg_2: f32) u8 {
//     return fn_ptr2.?(arg_1, arg_2);
// }
