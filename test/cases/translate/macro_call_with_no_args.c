#define CALL(arg) bar()
int bar(void) { return 0; }

// translate
// expect=fail
//
// pub inline fn CALL(arg: anytype) @TypeOf(bar()) {
//     _ = &arg;
//     return bar();
// }
