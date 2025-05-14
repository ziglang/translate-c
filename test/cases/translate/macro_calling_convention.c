#define SYSV_ABI __attribute__((sysv_abi))
void SYSV_ABI foo(void);


// translate
// target=x86_64-windows
//
// pub extern fn foo() callconv(.{ .x86_64_sysv = .{} }) void;
