#define NULL ((void*)0)
#define FOO ((int)0x8000)

// translate
//
// pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
//
// pub const FOO = __helpers.cast(c_int, __helpers.promoteIntLiteral(c_int, 0x8000, .hex));
