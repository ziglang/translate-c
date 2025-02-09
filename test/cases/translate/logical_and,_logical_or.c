int max(int a, int b) {
    if (a < b || a == b)
        return b;
    if (a >= b && a == b)
        return a;
    return a;
}

// translate
//
// pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     if ((a < b) or (a == b)) return b;
//     if ((a >= b) and (a == b)) return a;
//     return a;
// }
