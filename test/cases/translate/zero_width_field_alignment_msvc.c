struct __attribute__((packed)) foo {
  int x;
  struct {};
  float y;
  union {};
};

// translate
// target=native-windows-msvc
//
// const struct_unnamed_1 = extern struct {
//     _padding: u32 align(1) = 0,
// };
// const union_unnamed_2 = extern union {
//     _padding: u32 align(1),
// };
// pub const struct_foo = extern struct {
//     x: c_int align(1) = 0,
//     unnamed_0: struct_unnamed_1 = @import("std").mem.zeroes(struct_unnamed_1),
//     y: f32 align(1) = 0,
//     unnamed_1: union_unnamed_2 = @import("std").mem.zeroes(union_unnamed_2),
// };
