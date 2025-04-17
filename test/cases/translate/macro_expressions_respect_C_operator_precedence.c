int *foo = 0;
#define FOO *((foo) + 2)
#define VALUE  (1 + 2 * 3 + 4 * 5 + 6 << 7 | 8 == 9)
#define _AL_READ3BYTES(p)   ((*(unsigned char *)(p))            \
                             | (*((unsigned char *)(p) + 1) << 8)  \
                             | (*((unsigned char *)(p) + 2) << 16))

// translate
//
// pub inline fn FOO() @TypeOf((foo + @as(c_int, 2)).*) {
//     return (foo + @as(c_int, 2)).*;
// }
//
// pub const VALUE = ((((@as(c_int, 1) + (@as(c_int, 2) * @as(c_int, 3))) + (@as(c_int, 4) * @as(c_int, 5))) + @as(c_int, 6)) << @as(c_int, 7)) | @intFromBool(@as(c_int, 8) == @as(c_int, 9));
//
// pub inline fn _AL_READ3BYTES(p: anytype) @TypeOf((__helpers.cast([*c]u8, p).* | ((__helpers.cast([*c]u8, p) + @as(c_int, 1)).* << @as(c_int, 8))) | ((__helpers.cast([*c]u8, p) + @as(c_int, 2)).* << @as(c_int, 16))) {
//     _ = &p;
//     return (__helpers.cast([*c]u8, p).* | ((__helpers.cast([*c]u8, p) + @as(c_int, 1)).* << @as(c_int, 8))) | ((__helpers.cast([*c]u8, p) + @as(c_int, 2)).* << @as(c_int, 16));
// }
