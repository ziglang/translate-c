float static_local_bar;
float bar;
int foo() {
    _Thread_local static int bar = 2;
    (void)bar;
}

// translate
//
// pub export var static_local_bar: f32 = 0;
// pub export var bar: f32 = 0;
// pub export fn foo() c_int {
//     const static_local_bar_1 = struct {
//         threadlocal var bar: c_int = 2;
//     };
//     _ = &static_local_bar_1;
//     _ = static_local_bar_1.bar;
//     return undefined;
// }
