int max(const int x, int y) {
    return (x > y) ? x : y;
}

// translate
//
// pub export fn max(x: c_int, arg_y: c_int) c_int {
//     _ = &x;
//     var y = arg_y;
//     _ = &y;
//     return if (x > y) x else y;
// }
