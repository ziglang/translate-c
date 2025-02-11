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
// target=native-linux
//
// pub const struct_NAMED = extern struct {
//     name: c_long = 0,
// };
// pub const NAMED = struct_NAMED;
// pub const struct_ONENAMEWITHSTRUCT = extern struct {
//     b: c_long = 0,
// };
