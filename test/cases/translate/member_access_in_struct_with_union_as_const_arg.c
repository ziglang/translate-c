#define SUFFIXED(x) x##_suffix

struct my_struct {
  union {
    int SUFFIXED(internal);
    double d;
  };
};

int my_func(const struct my_struct* s) {
    return s->SUFFIXED(internal);
}

// translate
//
// const union_unnamed_1 = extern union {
//     internal_suffix: c_int,
//     d: f64,
// };
// pub const struct_my_struct = extern struct {
//     unnamed_0: union_unnamed_1 = @import("std").mem.zeroes(union_unnamed_1),
//     pub const my_func = __root.my_func;
//     pub const func = __root.my_func;
// };
// pub export fn my_func(arg_s: [*c]const struct_my_struct) c_int {
//     var s = arg_s;
//     _ = &s;
//     return s.*.unnamed_0.internal_suffix;
// }
