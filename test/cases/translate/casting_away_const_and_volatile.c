void foo(int *a) {}
void bar(const int *a) {
    foo((int *)a);
}
void baz(volatile int *a) {
    foo((int *)a);
}

// translate
//
// pub export fn foo(arg_a: [*c]c_int) void {
//     var a = arg_a;
//     _ = &a;
// }
// pub export fn bar(arg_a: [*c]const c_int) void {
//     var a = arg_a;
//     _ = &a;
//     foo(@ptrCast(@alignCast(@constCast(a))));
// }
// pub export fn baz(arg_a: [*c]volatile c_int) void {
//     var a = arg_a;
//     _ = &a;
//     foo(@ptrCast(@alignCast(@volatileCast(a))));
// }
