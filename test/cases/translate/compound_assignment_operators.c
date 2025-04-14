void foo(void) {
    int a = 0;
    unsigned b = 0;
    a += (a += 1);
    a -= (a -= 1);
    a *= (a *= 1);
    a &= (a &= 1);
    a |= (a |= 1);
    a ^= (a ^= 1);
    a >>= (a >>= 1);
    a <<= (a <<= 1);
    a /= (a /= 1);
    a %= (a %= 1);
    b /= (b /= 1);
    b %= (b %= 1);
}

// translate
//
// pub export fn foo() void {
//     var a: c_int = 0;
//     _ = &a;
//     var b: c_uint = 0;
//     _ = &b;
//     a += blk: {
//         const ref = &a;
//         ref.* += 1;
//         break :blk ref.*;
//     };
//     a -= blk: {
//         const ref = &a;
//         ref.* -= 1;
//         break :blk ref.*;
//     };
//     a *= blk: {
//         const ref = &a;
//         ref.* *= 1;
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
//     {
//         const ref = &a;
//         ref.* = @divTrunc(ref.*, blk: {
//             const ref_1 = &a;
//             ref_1.* = @divTrunc(ref_1.*, @as(c_int, 1));
//             break :blk ref_1.*;
//         });
//     }
//     {
//         const ref = &a;
//         ref.* = __helpers.signedRemainder(ref.*, blk: {
//             const ref_1 = &a;
//             ref_1.* = __helpers.signedRemainder(ref_1.*, @as(c_int, 1));
//             break :blk ref_1.*;
//         });
//     }
//     b /= blk: {
//         const ref = &b;
//         ref.* /= 1;
//         break :blk ref.*;
//     };
//     b %= blk: {
//         const ref = &b;
//         ref.* %= 1;
//         break :blk ref.*;
//     };
// }
