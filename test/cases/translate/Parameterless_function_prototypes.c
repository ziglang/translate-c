void a() {}
void b(void) {}
void c();
void d(void);
static void e() {}
static void f(void) {}
static void g();
static void h(void);

// translate
//
// pub export fn a() void {}
// pub export fn b() void {}
// pub extern fn c(...) void;
// pub extern fn d() void;
// pub fn e() callconv(.c) void {}
// pub fn f() callconv(.c) void {}
// pub extern fn g(...) void;
// pub extern fn h() void;
