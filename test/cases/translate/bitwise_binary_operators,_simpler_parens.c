int max(int a, int b) {
    return (a & b) ^ (a | b);
}

// translate
//
// pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     return (a & b) ^ (a | b);
// }
