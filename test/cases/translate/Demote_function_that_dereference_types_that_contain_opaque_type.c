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
// warning: struct demoted to opaque type - has opaque field
// pub const struct_outer = opaque {};
//
// warning: unable to translate function, demoted to extern
//
// pub extern fn deref(arg_s: ?*struct_outer) void;
