int max(int a, int b) {
    if (a < b)
        return b;

    if (a < b)
        return b;
    else
        return a;

    if (a < b) ; else ;
}

// translate
//
// pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     if (a < b) return b;
//     if (a < b) return b else return a;
//     if (a < b) {} else {}
//     return 0;
// }
