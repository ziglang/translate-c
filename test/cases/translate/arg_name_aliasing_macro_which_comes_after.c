void foo(int bar) {
    bar = 2;
}
#define bar 4

// translate
// expect=fail
//
// pub export fn foo(arg_bar_1: c_int) void {
//     var bar_1 = arg_bar_1;
//     _ = &bar_1;
//     bar_1 = 2;
// }
//
// pub const bar = @as(c_int, 4);
