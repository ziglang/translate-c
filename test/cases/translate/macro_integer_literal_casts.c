#define NULL ((void*)0)
#define FOO ((int)0x8000)

// translate
// expect=fail
//
// pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
//
// pub const FOO = @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x8000, .hex));
