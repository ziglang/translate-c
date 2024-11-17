struct FOO {int x; int y;};
int bar(void) {
    static struct FOO foo;
    return foo.x;
}

// translate
// expect=fail
//
// pub const struct_FOO = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
//     y: c_int = @import("std").mem.zeroes(c_int),
// };
// pub export fn bar() c_int {
//     const foo = struct {
//         var static: struct_FOO = @import("std").mem.zeroes(struct_FOO);
//     };
//     _ = &foo;
//     return foo.static.x;
// }
