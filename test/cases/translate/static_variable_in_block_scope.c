float bar;
int foo() {
    _Thread_local static int bar = 2;
}

// translate
// expect=fail
//
// pub export var bar: f32 = @import("std").mem.zeroes(f32);
// pub export fn foo() c_int {
//     const bar_1 = struct {
//         threadlocal var static: c_int = 2;
//     };
//     _ = &bar_1;
//     return 0;
// }
