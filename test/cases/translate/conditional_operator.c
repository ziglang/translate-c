int bar(void) {
    if (2 ? 5 : 5 ? 4 : 6) 2;
    return  2 ? 5 : 5 ? 4 : 6;
}

// translate
// expect=fail
//
// pub export fn bar() c_int {
//     if ((if (true) @as(c_int, 5) else if (true) @as(c_int, 4) else @as(c_int, 6)) != 0) {
//         _ = @as(c_int, 2);
//     }
//     return if (true) @as(c_int, 5) else if (true) @as(c_int, 4) else @as(c_int, 6);
// }
