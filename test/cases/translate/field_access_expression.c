extern struct Foo {
    int b;
}a;
float b = 2.0f;
void foo(void) {
    struct Foo *c;
    a.b;
    c->b;
}

// translate
//
// pub const struct_Foo = extern struct {
//     b: c_int = 0,
// };
// pub extern var a: struct_Foo;
// pub export var b: f32 = 2;
// pub export fn foo() void {
//     var c: [*c]struct_Foo = undefined;
//     _ = &c;
//     _ = a.b;
//     _ = c.*.b;
// }
// pub const Foo = struct_Foo;
