typedef struct Bar Bar;
typedef struct Foo Foo;

struct Foo {
    Foo *a;
};

struct Bar {
    Foo *a;
};

// translate
//
// pub const struct_Foo = extern struct {
//     a: [*c]Foo = null,
// };
// 
// pub const Foo = struct_Foo;
// 
// pub const struct_Bar = extern struct {
//     a: [*c]Foo = null,
// };
// 
// pub const Bar = struct_Bar;
