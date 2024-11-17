struct my_struct {
    unsigned a: 15;
    unsigned: 2;
    unsigned b: 15;
};
void initialize(void) {
    struct my_struct S = {.a = 1, .b = 2};
}

// translate
// expect=fail
//
// warning: local variable has opaque type
//
// warning: unable to translate function, demoted to extern
// pub extern fn initialize() void;
