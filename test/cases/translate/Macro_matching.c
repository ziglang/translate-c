#define FOO(X) (X ## U)

// translate
// expect=fail
//
// pub const FOO = @import("std").zig.c_translation.Macros.U_SUFFIX;
