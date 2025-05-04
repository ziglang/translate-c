struct Foo;
struct Foo *some_func(struct Foo *foo, int x);

// translate
//
// pub const struct_Foo = opaque {
//     pub const func = some_func;
// };
// pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
