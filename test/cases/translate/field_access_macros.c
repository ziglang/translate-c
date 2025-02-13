#define ARROW a->b
#define DOT a.b

// translate
// expect=fail
//
// pub inline fn ARROW() @TypeOf(a.*.b) {
//     return a.*.b;
// }
//
// pub inline fn DOT() @TypeOf(a.b) {
//     return a.b;
// }
