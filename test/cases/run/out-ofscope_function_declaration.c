int bar(int a) {
    extern int abs(int);
    return abs(a);
}
int foo() {
    return abs(-1);
}

// translate
//
// pub export fn bar(arg_a: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     const extern_local_abs = struct {
//         extern fn abs(c_int) c_int;
//     };
//     _ = &extern_local_abs;
//     return extern_local_abs.abs(a);
// }
// pub export fn foo() c_int {
//     const extern_local_abs = struct {
//         extern fn abs(c_int) c_int;
//     };
//     _ = &extern_local_abs;
//     return abs(-@as(c_int, 1));
// }