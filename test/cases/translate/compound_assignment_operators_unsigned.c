void foo(void) {
    unsigned a = 0;
    a += (a += 1);
    a -= (a -= 1);
    a *= (a *= 1);
    a &= (a &= 1);
    a |= (a |= 1);
    a ^= (a ^= 1);
    a >>= (a >>= 1);
    a <<= (a <<= 1);
}

// translate
//
// pub export fn foo() void {
//     var a: c_uint = 0;
//     _ = &a;
//     a +%= blk: {
//         const ref = &a;
//         ref.* +%= 1;
//         break :blk ref.*;
//     };
//     a -%= blk: {
//         const ref = &a;
//         ref.* -%= 1;
//         break :blk ref.*;
//     };
//     a *%= blk: {
//         const ref = &a;
//         ref.* *%= 1;
//         break :blk ref.*;
//     };
//     a &= blk: {
//         const ref = &a;
//         ref.* &= 1;
//         break :blk ref.*;
//     };
//     a |= blk: {
//         const ref = &a;
//         ref.* |= 1;
//         break :blk ref.*;
//     };
//     a ^= blk: {
//         const ref = &a;
//         ref.* ^= 1;
//         break :blk ref.*;
//     };
//     a >>= @intCast(blk: {
//         const ref = &a;
//         ref.* >>= @intCast(1);
//         break :blk ref.*;
//     });
//     a <<= @intCast(blk: {
//         const ref = &a;
//         ref.* <<= @intCast(1);
//         break :blk ref.*;
//     });
// }
