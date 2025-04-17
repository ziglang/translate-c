#define MIN(a, b) ((b) < (a) ? (b) : (a))
#define MAX(a, b) ((b) > (a) ? (b) : (a))

// translate
//
// pub inline fn MIN(a: anytype, b: anytype) @TypeOf(if (b < a) b else a) {
//     _ = &a;
//     _ = &b;
//     return if (b < a) b else a;
// }
//
// pub inline fn MAX(a: anytype, b: anytype) @TypeOf(if (b > a) b else a) {
//     _ = &a;
//     _ = &b;
//     return if (b > a) b else a;
// }
