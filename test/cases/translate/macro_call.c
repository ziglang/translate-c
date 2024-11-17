#define CALL(arg) bar(arg)
int bar(int x) { return x; }

// translate
// expect=fail
//
// pub inline fn CALL(arg: anytype) @TypeOf(bar(arg)) {
//     _ = &arg;
//     return bar(arg);
// }
