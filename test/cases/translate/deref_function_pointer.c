void foo(void) {}
int baz(void) { return 0; }
void bar(void) {
    void(*f)(void) = foo;
    int(*b)(void) = baz;
    f();
    (*(f))();
    foo();
    b();
    (*(b))();
    baz();
}

// translate
// expect=fail
//
// pub export fn foo() void {}
// pub export fn baz() c_int {
//     return 0;
// }
// pub export fn bar() void {
//     var f: ?*const fn () callconv(.c) void = &foo;
//     _ = &f;
//     var b: ?*const fn () callconv(.c) c_int = &baz;
//     _ = &b;
//     f.?();
//     f.?();
//     foo();
//     _ = b.?();
//     _ = b.?();
//     _ = baz();
// }
