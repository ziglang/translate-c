#define FOO(x) ((x >= 0) + (x >= 0))
#define BAR 1 && 2 > 4

// translate
//
// pub inline fn FOO(x: anytype) @TypeOf(@intFromBool(x >= @as(c_int, 0)) + @intFromBool(x >= @as(c_int, 0))) {
//     _ = &x;
//     return @intFromBool(x >= @as(c_int, 0)) + @intFromBool(x >= @as(c_int, 0));
// }
//
// pub const BAR = (@as(c_int, 1) != 0) and (@as(c_int, 2) > @as(c_int, 4));
