struct inner {
    _Atomic int a;
};
struct outer {
    int thing;
    struct inner sub_struct;
};
void deref(struct outer *s) {
    *s;
}

// translate
//
// pub const struct_inner = opaque {};
//
// pub const struct_outer = extern struct {
//     thing: c_int = 0,
//     sub_struct: struct_inner = @import("std").mem.zeroes(struct_inner),
// };
//
// warning: unable to translate function, demoted to extern
//
// pub extern fn deref(arg_s: ?*struct_outer) void;
