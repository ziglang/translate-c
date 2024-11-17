typedef void (*fnptr_ty)(void);
typedef __attribute__((cdecl)) void (*fnptr_attr_ty)(void);
struct foo {
    __attribute__((cdecl)) void (*foo)(void);
    void (*bar)(void);
    fnptr_ty baz;
    fnptr_attr_ty qux;
};

// translate
// expect=fail
//
// pub const fnptr_ty = ?*const fn () callconv(.c) void;
// pub const fnptr_attr_ty = ?*const fn () callconv(.c) void;
// pub const struct_foo = extern struct {
//     foo: ?*const fn () callconv(.c) void = @import("std").mem.zeroes(?*const fn () callconv(.c) void),
//     bar: ?*const fn () callconv(.c) void = @import("std").mem.zeroes(?*const fn () callconv(.c) void),
//     baz: fnptr_ty = @import("std").mem.zeroes(fnptr_ty),
//     qux: fnptr_attr_ty = @import("std").mem.zeroes(fnptr_attr_ty),
// };
