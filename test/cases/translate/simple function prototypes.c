void __attribute__((noreturn)) foo(void);
int bar(void);

// translate
//
// pub extern fn foo() noreturn;
// pub extern fn bar() c_int;
