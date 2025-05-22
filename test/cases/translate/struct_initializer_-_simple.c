typedef struct { int x; } foo;
struct {double x,y,z;} s0 = {1.2, 1.3};
struct {int sec,min,hour,day,mon,year;} s1 = {.day=31,12,2014,.sec=30,15,17};
struct {int x,y;} s2 = {.y = 2, .x=1};
foo s3 = { 123 };

// translate
//
// pub const foo = extern struct {
//     x: c_int = 0,
// };
// const struct_unnamed_1 = extern struct {
//     x: f64 = 0,
//     y: f64 = 0,
//     z: f64 = 0,
// };
// pub export var s0: struct_unnamed_1 = struct_unnamed_1{
//     .x = 1.2,
//     .y = 1.3,
//     .z = 0,
// };
// const struct_unnamed_2 = extern struct {
//     sec: c_int = 0,
//     min: c_int = 0,
//     hour: c_int = 0,
//     day: c_int = 0,
//     mon: c_int = 0,
//     year: c_int = 0,
// };
// pub export var s1: struct_unnamed_2 = struct_unnamed_2{
//     .sec = 30,
//     .min = 15,
//     .hour = 17,
//     .day = 31,
//     .mon = 12,
//     .year = 2014,
// };
// const struct_unnamed_3 = extern struct {
//     x: c_int = 0,
//     y: c_int = 0,
// };
// pub export var s2: struct_unnamed_3 = struct_unnamed_3{
//     .x = 1,
//     .y = 2,
// };
// pub export var s3: foo = foo{
//     .x = 123,
// };
