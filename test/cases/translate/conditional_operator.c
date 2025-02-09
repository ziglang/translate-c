int bar(void) {
    if (2 ? 5 : 5 ? 4 : 6) 2;
    return  2 ? 5 : 5 ? 4 : 6;
}

// translate
//
// pub export fn bar() c_int {
//     if ((if (true) 5 else if (true) 4 else 6) != 0) {
//         _ = 2;
//     }
//     return if (true) 5 else if (true) 4 else 6;
// }
