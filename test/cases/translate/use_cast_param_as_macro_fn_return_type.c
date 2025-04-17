// TODO https://github.com/Vexu/arocc/issues/848
// #include <stdint.h>
typedef __UINT32_TYPE__ uint32_t;

#define SYS_BASE_CACHED 0
#define MEM_PHYSICAL_TO_K0(x) (void*)((uint32_t)(x) + SYS_BASE_CACHED)

// translate
//
// pub inline fn MEM_PHYSICAL_TO_K0(x: anytype) ?*anyopaque {
//     _ = &x;
//     return __helpers.cast(?*anyopaque, __helpers.cast(u32, x) + SYS_BASE_CACHED);
// }
