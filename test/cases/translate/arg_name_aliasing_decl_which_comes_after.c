void foo(int bar) {
    bar = 2;
}
int bar = 4;

// translate
//
// pub export fn foo(arg_bar_1: c_int) void {
//     var bar_1 = arg_bar_1;
//     _ = &bar_1;
//     bar_1 = 2;
// }
// pub export var bar: c_int = 4;
