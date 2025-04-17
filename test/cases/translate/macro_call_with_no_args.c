#define CALL(arg) bar()
int bar(void) { return 0; }

// translate
//
// pub inline fn CALL(arg: anytype) @TypeOf(bar()) {
//     _ = &arg;
//     return bar();
// }
