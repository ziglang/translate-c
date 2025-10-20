struct my_struct {
    unsigned a: 15;
    unsigned: 2;
    unsigned b: 15;
};
void initialize(void) {
    struct my_struct S = {.a = 1, .b = 2};
}

// translate
//
// warning: struct demoted to opaque type - has bitfield
// pub const struct_my_struct = opaque {};
// pub export fn initialize() void {
//     const S = if (true) @compileError("local variable has opaque type");
//     _ = &S;
// }
