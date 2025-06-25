extern void (*fn_ptr)(void);
#define foo fn_ptr

extern char (*fn_ptr2)(int, float);
#define bar fn_ptr2

extern double y0(double);
void (*epoxy_glDrawTextureNV)(float y0);
#define glDrawTextureNV epoxy_glDrawTextureNV

// translate
//
// pub extern var fn_ptr: ?*const fn () callconv(.c) void;
//
// pub inline fn foo() void {
//     return fn_ptr.?();
// }
//
// pub extern var fn_ptr2: ?*const fn (c_int, f32) callconv(.c) u8;
//
// pub inline fn bar(arg: c_int, arg_1: f32) u8 {
//     return fn_ptr2.?(arg, arg_1);
// }
// 
// pub extern fn y0(f64) f64;
// pub export var epoxy_glDrawTextureNV: ?*const fn (y0: f32) callconv(.c) void = null;
// 
// pub inline fn glDrawTextureNV(y0_1: f32) void {
//     return epoxy_glDrawTextureNV.?(y0_1);
// }
