typedef struct Bar Bar;
typedef struct Foo Foo;

struct Foo {
    Foo *a;
};

struct Bar {
    Foo *a;
};

// translate
// expect=fail
//
// pub const struct_Foo = extern struct {
//     a: [*c]Foo = @import("std").mem.zeroes([*c]Foo),
// };
// 
// pub const Foo = struct_Foo;
// 
// pub const struct_Bar = extern struct {
//     a: [*c]Foo = @import("std").mem.zeroes([*c]Foo),
// };
// 
// pub const Bar = struct_Bar;
