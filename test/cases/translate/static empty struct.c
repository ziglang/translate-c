struct empty_struct {};

static inline void foo() {
    static struct empty_struct bar = {};
    (void)bar;
}

// translate
// target=x86_64-linux
//
// pub const struct_empty_struct = extern struct {};
// pub fn foo(...) callconv(.c) void {
//     const bar = struct {
//         var static: struct_empty_struct = struct_empty_struct{};
//     };
//     _ = &bar;
//     _ = bar.static;
// }
// pub const empty_struct = struct_empty_struct;
