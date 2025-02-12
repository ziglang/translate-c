void foo(void) {
    int a[10];
    int* x = a;

    char b[6];
    char* y = b;
}

// translate
//
// pub export fn foo() void {
//     var a: [10]c_int = undefined;
//     _ = &a;
//     var x: [*c]c_int = @ptrCast(@alignCast(&a));
//     _ = &x;
//     var b: [6]u8 = undefined;
//     _ = &b;
//     var y: [*c]u8 = @ptrCast(@alignCast(&b));
//     _ = &y;
// }
