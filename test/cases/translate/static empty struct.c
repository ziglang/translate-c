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
//     const static_local_bar = struct {
//         var bar: struct_empty_struct = struct_empty_struct{};
//     };
//     _ = &static_local_bar;
//     _ = static_local_bar.bar;
// }
//
// pub const empty_struct = struct_empty_struct;
