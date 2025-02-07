void max(int a) {
    int tmp;
    tmp = a;
    a = tmp;
}

// translate
//
// pub export fn max(arg_a: c_int) void {
//     var a = arg_a;
//     _ = &a;
//     var tmp: c_int = undefined;
//     _ = &tmp;
//     tmp = a;
//     a = tmp;
//     return;
// }
