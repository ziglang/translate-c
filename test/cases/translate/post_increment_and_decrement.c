void foo(void) {
    int i = 0;
    unsigned u = 0;
    i++;
    i--;
    u++;
    u--;
    i = i++;
    i = i--;
    u = u++;
    u = u--;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var i: c_int = 0;
//     _ = &i;
//     var u: c_uint = 0;
//     _ = &u;
//     i += 1;
//     i -= 1;
//     u +%= 1;
//     u -%= 1;
//     i = blk: {
//         const ref = &i;
//         const tmp = ref.*;
//         ref.* += 1;
//         break :blk tmp;
//     };
//     i = blk: {
//         const ref = &i;
//         const tmp = ref.*;
//         ref.* -= 1;
//         break :blk tmp;
//     };
//     u = blk: {
//         const ref = &u;
//         const tmp = ref.*;
//         ref.* +%= 1;
//         break :blk tmp;
//     };
//     u = blk: {
//         const ref = &u;
//         const tmp = ref.*;
//         ref.* -%= 1;
//         break :blk tmp;
//     };
// }
