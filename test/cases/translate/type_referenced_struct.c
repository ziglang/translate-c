// When clang uses the <arch>-windows-none, triple it behaves as MSVC and
// interprets the inner `struct Bar` as an anonymous structure
struct Foo {
    struct Bar{
        int b;
    };
    struct Bar c;
};

// translate
// target=x86_64-linux-gnu
//
// pub const struct_Bar_1 = extern struct {
//     b: c_int = 0,
// };
// pub const struct_Foo = extern struct {
//     c: struct_Bar_1 = @import("std").mem.zeroes(struct_Bar_1),
// };
