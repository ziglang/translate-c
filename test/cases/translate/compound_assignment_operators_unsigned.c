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
// expect=fail
//
// pub export fn foo() void {
//     var a: c_uint = 0;
//     _ = &a;
//     a +%= blk: {
//         const ref = &a;
//         ref.* +%= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a -%= blk: {
//         const ref = &a;
//         ref.* -%= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a *%= blk: {
//         const ref = &a;
//         ref.* *%= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a &= blk: {
//         const ref = &a;
//         ref.* &= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a |= blk: {
//         const ref = &a;
//         ref.* |= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a ^= blk: {
//         const ref = &a;
//         ref.* ^= @as(c_uint, @bitCast(@as(c_int, 1)));
//         break :blk ref.*;
//     };
//     a >>= @intCast(blk: {
//         const ref = &a;
//         ref.* >>= @intCast(@as(c_int, 1));
//         break :blk ref.*;
//     });
//     a <<= @intCast(blk: {
//         const ref = &a;
//         ref.* <<= @intCast(@as(c_int, 1));
//         break :blk ref.*;
//     });
// }
