void __attribute__((fastcall)) foo1(float *a);
void __attribute__((stdcall)) foo2(float *a);
void __attribute__((vectorcall)) foo3(float *a);
void __attribute__((cdecl)) foo4(float *a);
void __attribute__((thiscall)) foo5(float *a);

// translate
// expect=fail
// target=x86-linux-none
//
// pub extern fn foo1(a: [*c]f32) callconv(.{ .x86_fastcall = .{} }) void;
// pub extern fn foo2(a: [*c]f32) callconv(.{ .x86_stdcall = .{} }) void;
// pub extern fn foo3(a: [*c]f32) callconv(.{ .x86_vectorcall = .{} }) void;
// pub extern fn foo4(a: [*c]f32) void;
// pub extern fn foo5(a: [*c]f32) callconv(.{ .x86_thiscall = .{} }) void;
