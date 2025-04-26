typedef enum {
    FooA,
    FooB,
} Foo;
typedef struct {
    int a, b;
} Bar;

// translate
// target=native-linux
//
// pub const FooA: c_int = 0;
// pub const FooB: c_int = 1;
// pub const Foo = c_uint;
// pub const Bar = extern struct {
//     a: c_int = 0,
//     b: c_int = 0,
// };
