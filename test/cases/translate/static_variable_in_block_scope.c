float bar;
int foo() {
    _Thread_local static int bar = 2;
    (void)bar;
}

// translate
//
// pub export var bar: f32 = 0;
// pub export fn foo() c_int {
//     const bar_1 = struct {
//         threadlocal var static: c_int = 2;
//     };
//     _ = &bar_1;
//     _ = bar_1.static;
//     return undefined;
// }
