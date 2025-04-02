int foo(void) {
    extern int bar(int, int);
    return bar(1, 2);
}

// translate
//
// pub export fn foo() c_int {
//     const extern_local_bar = struct {
//         extern fn bar(c_int, c_int) c_int;
//     };
//     _ = &extern_local_bar;
//     return extern_local_bar.bar(1, 2);
// }
