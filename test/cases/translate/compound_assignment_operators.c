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
//     a = @divTrunc(a, blk: {
//         const ref = &a;
//         ref.* = @divTrunc(ref.*, 1);
//         break :blk ref.*;
//     });
//     a = __helpers.signedRemainder(a, blk: {
//         const ref = &a;
//         ref.* = __helpers.signedRemainder(ref.*, 1);
//         break :blk ref.*;
//     });
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
