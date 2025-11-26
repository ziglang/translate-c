int *a = (int*)(&a + 1); // TODO result missing casts

extern void *alloc(unsigned long long);
void foo(void) {
    int b = b + 1;
    int *c = alloc(sizeof(*c));
    const double *d = alloc(sizeof(*d));
}

// translate
//
// pub export var a: [*c]c_int = @ptrCast(@alignCast((&a) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1)))))));
// pub extern fn alloc(c_ulonglong) ?*anyopaque;
// pub export fn foo() void {
//     var b: c_int = undefined;
//     b = b + @as(c_int, 1);
//     _ = &b;
//     var c: [*c]c_int = undefined;
//     c = @ptrCast(@alignCast(alloc(@sizeOf(@TypeOf(c.*)))));
//     _ = &c;
//     var d: [*c]const f64 = undefined;
//     d = @ptrCast(@alignCast(alloc(@sizeOf(@TypeOf(d.*)))));
//     _ = &d;
// }
