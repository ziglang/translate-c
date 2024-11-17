extern int foo[];

// translate
// expect=fail
//
// const foo: [*c]c_int = @extern([*c]c_int, .{
//     .name = "foo",
// });
