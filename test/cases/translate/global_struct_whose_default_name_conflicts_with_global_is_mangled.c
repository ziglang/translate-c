struct foo {
    int x;
};
const char *struct_foo = "hello world";

// translate
// expect=fail
//
// pub const struct_foo_1 = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
// };
// 
// pub const foo = struct_foo_1;
// 
// pub export var struct_foo: [*c]const u8 = "hello world";
