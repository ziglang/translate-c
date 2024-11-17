int max(int a, int b) {
    if (a == b)
        return a;
    if (a != b)
        return b;
    return a;
}

// translate
// expect=fail
//
// pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     if (a == b) return a;
//     if (a != b) return b;
//     return a;
// }
