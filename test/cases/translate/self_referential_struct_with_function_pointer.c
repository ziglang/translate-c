struct Foo {
    void (*derp)(struct Foo *foo);
};

// translate
//
// pub const struct_Foo = extern struct {
//     derp: ?*const fn (foo: [*c]struct_Foo) callconv(.c) void = null,
// };
//
// pub const Foo = struct_Foo;
