typedef struct NAMED
{
    long name;
} NAMED;

typedef struct ONENAMEWITHSTRUCT
{
    NAMED;
    long b;
} ONENAMEWITHSTRUCT;

// translate
// target=native-windows-msvc
//
// pub const struct_NAMED = extern struct {
//     name: c_long = 0,
// };
// pub const NAMED = struct_NAMED;
// pub const struct_ONENAMEWITHSTRUCT = extern struct {
//     unnamed_0: NAMED = @import("std").mem.zeroes(NAMED),
//     b: c_long = 0,
// };
// pub const ONENAMEWITHSTRUCT = struct_ONENAMEWITHSTRUCT;
