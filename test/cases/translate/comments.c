#define foo 1 //foo
#define bar /* bar */ 2

// translate
// expect=fail
//
// pub const foo = @as(c_int, 1);
//
// pub const bar = @as(c_int, 2);
