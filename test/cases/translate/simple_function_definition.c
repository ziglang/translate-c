void foo(void) {}
static void bar(void) {}

// translate
//
// pub export fn foo() void {}
// pub fn bar() callconv(.c) void {}
