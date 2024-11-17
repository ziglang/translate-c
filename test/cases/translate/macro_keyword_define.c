#define foo 1
#define inline 2

// translate
// expect=fail
//
// pub const foo = @as(c_int, 1);
//
// pub const @"inline" = @as(c_int, 2);
