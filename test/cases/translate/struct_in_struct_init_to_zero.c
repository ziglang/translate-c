struct Foo {
    int a;
    struct Bar {
        int a;
    } b;
} a = {};

// translate
//
// pub const struct_Bar_1 = extern struct {
//     a: c_int = 0,
// };
// pub const struct_Foo = extern struct {
//     a: c_int = 0,
//     b: struct_Bar_1 = @import("std").mem.zeroes(struct_Bar_1),
// };
// pub export var a: struct_Foo = struct_Foo{
//     .a = 0,
//     .b = @import("std").mem.zeroes(struct_Bar_1),
// };
