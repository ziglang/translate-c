int foo(int *p, int x) {
    return *p++ = x;
}

// translate
//
// pub export fn foo(arg_p: [*c]c_int, arg_x: c_int) c_int {
//     var p = arg_p;
//     _ = &p;
//     var x = arg_x;
//     _ = &x;
//     return blk: {
//         const tmp = x;
//         (blk_1: {
//             const ref = &p;
//             const tmp_2 = ref.*;
//             ref.* += 1;
//             break :blk_1 tmp_2;
//         }).* = tmp;
//         break :blk tmp;
//     };
// }
