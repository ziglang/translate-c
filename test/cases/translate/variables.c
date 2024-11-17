extern int extern_var;
static const int int_var = 13;
int foo;

// translate
// expect=fail
//
// pub extern var extern_var: c_int;
// pub const int_var: c_int = 13;
// pub export var foo: c_int = @import("std").mem.zeroes(c_int);
