struct A {
    _Atomic int a;
} a;
int main(void) {
    struct A b;
}

// translate
//
// warning: TODO support atomic type: '_Atomic(int)'
//
// warning: struct demoted to opaque type - unable to translate type of field a
// pub const struct_A = opaque {};
// pub const a = @compileError("non-extern variable has opaque type");
//
// pub export fn main() c_int {
//     pub const b = @compileError("local variable has opaque type");
//     _ = &b;
//     return 0;
// }
