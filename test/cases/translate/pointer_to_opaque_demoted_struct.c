typedef struct {
    _Atomic int foo;
} Foo;

typedef struct {
    Foo *bar;
} Bar;

// translate
// expect=fail
//
// source.h:1:9: warning: struct demoted to opaque type - unable to translate type of field foo
// pub const Foo = opaque {};
// pub const Bar = extern struct {
//     bar: ?*Foo = @import("std").mem.zeroes(?*Foo),
// };
