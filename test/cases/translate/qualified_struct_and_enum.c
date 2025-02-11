struct Foo {
    int x;
    int y;
};
enum Bar {
    BarA,
    BarB,
};
void func(struct Foo *a, enum Bar **b);

// translate
// target=x86_64-linux
//
// pub const struct_Foo = extern struct {
//     x: c_int = 0,
//     y: c_int = 0,
// };
// pub const BarA: c_int = 0;
// pub const BarB: c_int = 1;
// pub const enum_Bar = c_uint;
// pub extern fn func(a: [*c]struct_Foo, b: [*c][*c]enum_Bar) void;
//
// pub const Foo = struct_Foo;
// pub const Bar = enum_Bar;
