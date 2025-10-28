struct Foo;
struct Foo *some_func(struct Foo *foo, int x);

// translate
//
// pub const struct_Foo = opaque {
//     pub const some_func = __root.some_func;
//     pub const func = __root.some_func;
// };
// pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
