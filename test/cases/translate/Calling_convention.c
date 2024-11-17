void __attribute__((aarch64_vector_pcs)) foo1(float *a);

// translate
// expect=fail
// target=aarch64-linux-none
//
// pub extern fn foo1(a: [*c]f32) callconv(.{ .aarch64_vfabi = .{} }) void;
