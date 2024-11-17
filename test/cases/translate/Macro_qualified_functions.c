void __attribute__((sysv_abi)) foo(void);

// translate
// expect=fail
//
// pub extern fn foo() void;
