 int a, b, c;
#define FOO a ? b : c

// translate
// expect=fail
//
// pub inline fn FOO() @TypeOf(if (a) b else c) {
//     return if (a) b else c;
// }
