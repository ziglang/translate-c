#include <stdint.h>
int baz(void *arg) { return 0; }
#define FOO(bar) baz((void *)(baz))
#define BAR (void*) a
#define BAZ (uint32_t)(2)
#define a 2

// translate
// expect=fail
//
// pub inline fn FOO(bar: anytype) @TypeOf(baz(@import("std").zig.c_translation.cast(?*anyopaque, baz))) {
//     _ = &bar;
//     return baz(@import("std").zig.c_translation.cast(?*anyopaque, baz));
// }
//
// pub const BAR = @import("std").zig.c_translation.cast(?*anyopaque, a);
//
// pub const BAZ = @import("std").zig.c_translation.cast(u32, @as(c_int, 2));
