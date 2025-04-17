struct foo { int x; int y[]; };
struct bar { int x; int y[0]; };

// translate
// expect=fail
//
// pub const struct_foo = extern struct {
//     x: c_int align(4) = @import("std").mem.zeroes(c_int),
//     pub fn y(self: anytype) __helpers.FlexibleArrayType(@TypeOf(self), c_int) {
//         const Intermediate = __helpers.FlexibleArrayType(@TypeOf(self), u8);
//         const ReturnType = __helpers.FlexibleArrayType(@TypeOf(self), c_int);
//         return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 4)));
//     }
// };
// pub const struct_bar = extern struct {
//     x: c_int align(4) = @import("std").mem.zeroes(c_int),
//     pub fn y(self: anytype) __helpers.FlexibleArrayType(@TypeOf(self), c_int) {
//         const Intermediate = __helpers.FlexibleArrayType(@TypeOf(self), u8);
//         const ReturnType = __helpers.FlexibleArrayType(@TypeOf(self), c_int);
//         return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 4)));
//     }
// };
