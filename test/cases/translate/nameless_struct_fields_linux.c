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
// expect=fail
// target=native-linux
//
// pub const struct_NAMED = extern struct {
//     name: c_long = @import("std").mem.zeroes(c_long),
// };
// pub const NAMED = struct_NAMED;
// pub const struct_ONENAMEWITHSTRUCT = extern struct {
//     b: c_long = @import("std").mem.zeroes(c_long),
// };
