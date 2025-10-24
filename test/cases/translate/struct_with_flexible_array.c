struct foo { int x; int y[]; };
struct bar { int x; int y[0]; };

// translate
//
// pub const struct_foo = extern struct {
//     x: c_int = 0,
//     _y: [0]c_int = @import("std").mem.zeroes([0]c_int),
//     pub fn y(self: anytype) __helpers.FlexibleArrayType(@TypeOf(self), @typeInfo(@TypeOf(self.*._y)).array.child) {
//         return @ptrCast(@alignCast(&self.*._y));
//     }
// };
// pub const struct_bar = extern struct {
//     x: c_int = 0,
//     _y: [0]c_int = @import("std").mem.zeroes([0]c_int),
//     pub fn y(self: anytype) __helpers.FlexibleArrayType(@TypeOf(self), @typeInfo(@TypeOf(self.*._y)).array.child) {
//         return @ptrCast(@alignCast(&self.*._y));
//     }
// };
