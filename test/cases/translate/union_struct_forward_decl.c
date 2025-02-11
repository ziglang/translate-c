struct A;
union B;
enum C;

struct A {
  short x;
  double y;
};

union B {
  short x;
  double y;
};

struct Foo {
  struct A a;
  union B b;
};


// translate
//
// pub const struct_A = extern struct {
//     x: c_short = 0,
//     y: f64 = 0,
// };
//
// pub const union_B = extern union {
//     x: c_short,
//     y: f64,
// };
// 
// pub const struct_Foo = extern struct {
//     a: struct_A = @import("std").mem.zeroes(struct_A),
//     b: union_B = @import("std").mem.zeroes(union_B),
// };
