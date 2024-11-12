union Foo {
    int x;
};

// translate
//
// pub const union_Foo = extern union {
//     x: c_int,
// };
// 
// pub const Foo = union_Foo;
