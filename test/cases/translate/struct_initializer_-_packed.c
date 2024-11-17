struct {int x,y,z;} __attribute__((packed)) s0 = {1, 2};

// translate
// expect=fail
//
// const struct_unnamed_1 = extern struct {
//     x: c_int align(1) = @import("std").mem.zeroes(c_int),
//     y: c_int align(1) = @import("std").mem.zeroes(c_int),
//     z: c_int align(1) = @import("std").mem.zeroes(c_int),
// };
// pub export var s0: struct_unnamed_1 = struct_unnamed_1{
//     .x = @as(c_int, 1),
//     .y = @as(c_int, 2),
//     .z = 0,
// };
