typedef enum {
    FooA,
    FooB,
} Foo;
typedef struct {
    int a, b;
} Bar;

// translate
// expect=fail
//
// pub const FooA: c_int = 0;
// pub const FooB: c_int = 1;
// pub const Foo = c_uint;
// pub const Bar = extern struct {
//     a: c_int = @import("std").mem.zeroes(c_int),
//     b: c_int = @import("std").mem.zeroes(c_int),
// };
