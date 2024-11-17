#define foo (foo, bar)
int baz(int x, int y) { return 0; }
#define bar(x) (&x, +3, 4 == 4, 5 * 6, baz(1, 2), 2 % 2, baz(1,2))

// translate
// expect=fail
//
// pub const foo = blk_1: {
//     _ = &foo;
//     break :blk_1 bar;
// };
//
// pub inline fn bar(x: anytype) @TypeOf(baz(@as(c_int, 1), @as(c_int, 2))) {
//     _ = &x;
//     return blk_1: {
//         _ = &x;
//         _ = @as(c_int, 3);
//         _ = @as(c_int, 4) == @as(c_int, 4);
//         _ = @as(c_int, 5) * @as(c_int, 6);
//         _ = baz(@as(c_int, 1), @as(c_int, 2));
//         _ = @import("std").zig.c_translation.MacroArithmetic.rem(@as(c_int, 2), @as(c_int, 2));
//         break :blk_1 baz(@as(c_int, 1), @as(c_int, 2));
//     };
// }
