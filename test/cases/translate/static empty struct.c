struct empty_struct {};

static inline void foo() {
    static struct empty_struct bar = {};
}

// translate
// target=x86_64-linux
// expect=fail
//
// pub const struct_empty_struct = extern struct {};
// pub fn foo() callconv(.c) void {
//     const bar = struct {
//         var static: struct_empty_struct = @import("std").mem.zeroes(struct_empty_struct);
//     };
//     _ = &bar;
// }
