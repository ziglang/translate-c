typedef struct { int x; } foo;
struct {double x,y,z;} s0 = {1.2, 1.3};
struct {int sec,min,hour,day,mon,year;} s1 = {.day=31,12,2014,.sec=30,15,17};
struct {int x,y;} s2 = {.y = 2, .x=1};
foo s3 = { 123 };

// translate
// expect=fail
//
// pub const foo = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
// };
// const struct_unnamed_1 = extern struct {
//     x: f64 = @import("std").mem.zeroes(f64),
//     y: f64 = @import("std").mem.zeroes(f64),
//     z: f64 = @import("std").mem.zeroes(f64),
// };
// pub export var s0: struct_unnamed_1 = struct_unnamed_1{
//     .x = 1.2,
//     .y = 1.3,
//     .z = 0,
// };
// const struct_unnamed_2 = extern struct {
//     sec: c_int = @import("std").mem.zeroes(c_int),
//     min: c_int = @import("std").mem.zeroes(c_int),
//     hour: c_int = @import("std").mem.zeroes(c_int),
//     day: c_int = @import("std").mem.zeroes(c_int),
//     mon: c_int = @import("std").mem.zeroes(c_int),
//     year: c_int = @import("std").mem.zeroes(c_int),
// };
// pub export var s1: struct_unnamed_2 = struct_unnamed_2{
//     .sec = @as(c_int, 30),
//     .min = @as(c_int, 15),
//     .hour = @as(c_int, 17),
//     .day = @as(c_int, 31),
//     .mon = @as(c_int, 12),
//     .year = @as(c_int, 2014),
// };
// const struct_unnamed_3 = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
//     y: c_int = @import("std").mem.zeroes(c_int),
// };
// pub export var s2: struct_unnamed_3 = struct_unnamed_3{
//     .x = @as(c_int, 1),
//     .y = @as(c_int, 2),
// };
// pub export var s3: foo = foo{
//     .x = @as(c_int, 123),
// };
