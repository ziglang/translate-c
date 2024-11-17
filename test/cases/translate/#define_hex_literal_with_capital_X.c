#define VAL 0XF00D

// translate
// expect=fail
//
// pub const VAL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xF00D, .hex);
