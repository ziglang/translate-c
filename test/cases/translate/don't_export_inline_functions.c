inline void a(void) {}
static void b(void) {}
void c(void) {}
static void foo() {}

// translate
//
// pub fn a() callconv(.c) void {}
// pub fn b() callconv(.c) void {}
// pub export fn c() void {}
// pub fn foo() callconv(.c) void {}
