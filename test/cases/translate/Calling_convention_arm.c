void __attribute__((pcs("aapcs"))) foo1(float *a);
void __attribute__((pcs("aapcs-vfp"))) foo2(float *a);

// translate
// expect=fail
// target=arm-linux-none
//
// pub extern fn foo1(a: [*c]f32) callconv(.{ .arm_aapcs = .{} }) void;
// pub extern fn foo2(a: [*c]f32) callconv(.{ .arm_aapcs_vfp = .{} }) void;
