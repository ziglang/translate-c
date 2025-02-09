typedef void (*fnptr_ty)(void);
typedef __attribute__((cdecl)) void (*fnptr_attr_ty)(void);
struct foo {
    __attribute__((cdecl)) void (*foo)(void);
    void (*bar)(void);
    fnptr_ty baz;
    fnptr_attr_ty qux;
};

// translate
//
// pub const fnptr_ty = ?*const fn () callconv(.c) void;
// pub const fnptr_attr_ty = ?*const fn () callconv(.c) void;
// pub const struct_foo = extern struct {
//     foo: ?*const fn () callconv(.c) void = null,
//     bar: ?*const fn () callconv(.c) void = null,
//     baz: fnptr_ty = null,
//     qux: fnptr_attr_ty = null,
// };
