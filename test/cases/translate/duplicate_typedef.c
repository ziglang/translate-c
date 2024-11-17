typedef long foo;
typedef int bar;
typedef long foo;
typedef int baz;

// translate
// expect=fail
//
// pub const foo = c_long;
// pub const bar = c_int;
// pub const baz = c_int;
