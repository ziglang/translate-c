struct Bar;

struct Foo {
    struct Bar *next;
};

struct Bar {
    struct Foo *next;
};

// translate
//
// pub const struct_Bar = extern struct {
//     next: [*c]struct_Foo = null,
// };
// 
// pub const struct_Foo = extern struct {
//     next: [*c]struct_Bar = null,
// };
