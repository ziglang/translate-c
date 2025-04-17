#include <stdint.h>
#define SYS_BASE_CACHED 0
#define MEM_PHYSICAL_TO_K0(x) (void*)((uint32_t)(x) + SYS_BASE_CACHED)

// translate
//
// pub inline fn MEM_PHYSICAL_TO_K0(x: anytype) ?*anyopaque {
//     _ = &x;
//     return __helpers.cast(?*anyopaque, __helpers.cast(u32, x) + SYS_BASE_CACHED);
// }
