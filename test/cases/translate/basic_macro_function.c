extern int c;
#define BASIC(c) (c*2)
#define FOO(L,b) (L + b)
#define BAR() (c*c)

// translate
//
// pub extern var c: c_int;
//
// pub inline fn BASIC(c_1: anytype) @TypeOf(c_1 * @as(c_int, 2)) {
//     _ = &c_1;
//     return c_1 * @as(c_int, 2);
// }
//
// pub inline fn FOO(L: anytype, b: anytype) @TypeOf(L + b) {
//     _ = &L;
//     _ = &b;
//     return L + b;
// }
//
// pub inline fn BAR() @TypeOf(c * c) {
//     return c * c;
// }
