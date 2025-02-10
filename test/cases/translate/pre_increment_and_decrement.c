void foo(void) {
    int i = 0;
    unsigned u = 0;
    ++i;
    --i;
    ++u;
    --u;
    i = ++i;
    i = --i;
    u = ++u;
    u = --u;
}

// translate
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
//         ref.* += 1;
//         break :blk ref.*;
//     };
//     i = blk: {
//         const ref = &i;
//         ref.* -= 1;
//         break :blk ref.*;
//     };
//     u = blk: {
//         const ref = &u;
//         ref.* +%= 1;
//         break :blk ref.*;
//     };
//     u = blk: {
//         const ref = &u;
//         ref.* -%= 1;
//         break :blk ref.*;
//     };
// }
