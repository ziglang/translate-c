struct Foo {
    int x;
};

// translate
//
// const struct_Foo = extern struct {
//     x: c_int = 0,
// };
// 
// pub const Foo = struct_Foo;
