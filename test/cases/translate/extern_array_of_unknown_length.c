extern int foo[];

// translate
//
// const foo: [*c]c_int = @extern([*c]c_int, .{
//     .name = "foo",
// });
