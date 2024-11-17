typedef struct Color {
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
} Color;
#define CLITERAL(type)      (type)
#define LIGHTGRAY  CLITERAL(Color){ 200, 200, 200, 255 }   // Light Gray
typedef struct boom_t
{
    int i1;
} boom_t;
#define FOO ((boom_t){1})
typedef struct { float x; } MyCStruct;
#define A(_x)   (MyCStruct) { .x = (_x) }
#define B A(0.f)

// translate
// expect=fail
//
// pub const struct_Color = extern struct {
//     r: u8 = @import("std").mem.zeroes(u8),
//     g: u8 = @import("std").mem.zeroes(u8),
//     b: u8 = @import("std").mem.zeroes(u8),
//     a: u8 = @import("std").mem.zeroes(u8),
// };
// pub const Color = struct_Color;
//
// pub inline fn CLITERAL(@"type": anytype) @TypeOf(@"type") {
//     _ = &@"type";
//     return @"type";
// }
//
// pub const LIGHTGRAY = @import("std").mem.zeroInit(CLITERAL(Color), .{ @as(c_int, 200), @as(c_int, 200), @as(c_int, 200), @as(c_int, 255) });
//
// pub const struct_boom_t = extern struct {
//     i1: c_int = @import("std").mem.zeroes(c_int),
// };
// pub const boom_t = struct_boom_t;
//
// pub const FOO = @import("std").mem.zeroInit(boom_t, .{@as(c_int, 1)});
//
// pub const MyCStruct = extern struct {
//     x: f32 = @import("std").mem.zeroes(f32),
// };
//
// pub inline fn A(_x: anytype) MyCStruct {
//     _ = &_x;
//     return @import("std").mem.zeroInit(MyCStruct, .{
//         .x = _x,
//     });
// }
//
// pub const B = A(@as(f32, 0));
