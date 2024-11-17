#define MAP_FAILED ((void *) -1)
typedef long long LONG_PTR;
#define INVALID_HANDLE_VALUE ((void *)(LONG_PTR)-1)

// translate
// expect=fail
//
// pub const MAP_FAILED = @import("std").zig.c_translation.cast(?*anyopaque, -@as(c_int, 1));
// pub const INVALID_HANDLE_VALUE = @import("std").zig.c_translation.cast(?*anyopaque, @import("std").zig.c_translation.cast(LONG_PTR, -@as(c_int, 1)));
