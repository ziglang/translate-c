struct Foo {
    void (*derp)(struct Foo *foo);
};

// translate
// expect=fail
//
// pub const struct_Foo = extern struct {
//     derp: ?*const fn ([*c]struct_Foo) callconv(.c) void = @import("std").mem.zeroes(?*const fn ([*c]struct_Foo) callconv(.c) void),
// };
//
// pub const Foo = struct_Foo;
