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
// target=native-windows-msvc
//
// pub const struct_NAMED = extern struct {
//     name: c_long = @import("std").mem.zeroes(c_long),
// };
// pub const NAMED = struct_NAMED;
// pub const struct_ONENAMEWITHSTRUCT = extern struct {
//     unnamed_0: struct_NAMED =  = @import("std").mem.zeroes(struct_NAMED),
//     b: c_long = @import("std").mem.zeroes(c_long),
// };
