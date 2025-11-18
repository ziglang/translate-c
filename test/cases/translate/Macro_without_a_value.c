#define FOO
#define BAR(x)

// translate
//
// pub const FOO = "";
//
// pub inline fn BAR(x: anytype) void {
//     _ = &x;
//     return;
// }
