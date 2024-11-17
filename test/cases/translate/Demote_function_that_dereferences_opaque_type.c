struct my_struct {
    unsigned a: 1;
};
void deref(struct my_struct *s) {
    *s;
}

// translate
// expect=fail
//
// warning: cannot dereference opaque type
//
// warning: unable to translate function, demoted to extern
// pub extern fn deref(arg_s: ?*struct_my_struct) void;
