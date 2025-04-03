static void bar(void) { }
void foo(int *(baz)(void)) {
    bar();
    baz();
}

// translate
//
// pub fn bar() callconv(.c) void {}
// pub export fn foo(arg_baz: ?*const fn () callconv(.c) [*c]c_int) void {
//     var baz = arg_baz;
//     _ = &baz;
//     bar();
//     _ = baz.?();
// }
