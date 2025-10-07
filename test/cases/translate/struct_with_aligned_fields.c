struct foo {
    __attribute__((aligned(4))) short bar;
};

struct over_aligned_array_head {
    __attribute__((aligned(16))) float bar[4];
};

struct over_aligned_array_padding {
    float a;
    short b;
    __attribute__((aligned(16))) float bar[4];
};

// translate
// 
// pub const struct_foo = extern struct {
//     bar: c_short align(4) = 0,
// };
//
// pub const struct_over_aligned_array_head = extern struct {
//     bar: [4]f32 align(16) = @import("std").mem.zeroes([4]f32),
// };
//
// pub const struct_over_aligned_array_padding = extern struct {
//     a: f32 align(16) = 0,
//     b: c_short = 0,
//     bar: [4]f32 align(16) = @import("std").mem.zeroes([4]f32),
// };
