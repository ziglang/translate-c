struct Foo {
    unsigned int: 1;
};
struct Bar {
    struct Foo *foo;
};

// translate
//
// pub const struct_Foo = opaque {};
// 
// pub const struct_Bar = extern struct {
//     foo: ?*struct_Foo = null,
// };
