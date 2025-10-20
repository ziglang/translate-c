typedef struct {
    _Atomic int foo;
} Foo;

typedef struct {
    Foo *bar;
} Bar;

// translate
//
// :2:17: warning: struct demoted to opaque type - unable to translate type of field foo
// pub const Foo = opaque {};
//
// warning: struct demoted to opaque type - unable to translate type of field foo
// pub const Foo = opaque {};
