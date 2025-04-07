struct FOO {int x; int y;};
int bar(void) {
    static struct FOO foo;
    return foo.x;
}

// translate
//
// pub const struct_FOO = extern struct {
//     x: c_int = 0,
//     y: c_int = 0,
// };
// pub export fn bar() c_int {
//     const static_local_foo = struct {
//         var foo: struct_FOO = @import("std").mem.zeroes(struct_FOO);
//     };
//     _ = &static_local_foo;
//     return static_local_foo.foo.x;
// }
//
// pub const FOO = struct_FOO;
