// TODO https://github.com/Vexu/arocc/issues/848
// #include <stdint.h>
typedef __UINT32_TYPE__ uint32_t;

int baz(void *arg) { return 0; }
#define FOO(bar) baz((void *)(baz))
#define BAR (void*) a
#define BAZ (uint32_t)(2)
#define a 2

// translate
//
// pub inline fn FOO(bar: anytype) @TypeOf(baz(__helpers.cast(?*anyopaque, baz))) {
//     _ = &bar;
//     return baz(__helpers.cast(?*anyopaque, baz));
// }
//
// pub const BAR = __helpers.cast(?*anyopaque, a);
//
// pub const BAZ = __helpers.cast(u32, @as(c_int, 2));
