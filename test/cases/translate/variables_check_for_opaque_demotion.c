struct A {
    _Atomic int a;
} a;
int main(void) {
    struct A a;
}

// translate
// expect=fail
//
// pub const struct_A = opaque {};
// pub const a = @compileError("non-extern variable has opaque type");
//
// pub extern fn main() c_int;
