void foo(void) {
    int a;
    char b = 123;
    const int c;
    const unsigned d = 440;
    int e = 10;
    unsigned int f = 10u;
    short g = e;
    unsigned short h = e;
    const unsigned i = 4294967297;
}

// translate
// target=x86_64-linux
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: u8 = 123;
//     _ = &b;
//     const c: c_int = undefined;
//     _ = &c;
//     const d: c_uint = 440;
//     _ = &d;
//     var e: c_int = 10;
//     _ = &e;
//     var f: c_uint = 10;
//     _ = &f;
//     var g: c_short = @truncate(e);
//     _ = &g;
//     var h: c_ushort = @bitCast(@as(c_short, @truncate(e)));
//     _ = &h;
//     const i: c_uint = @bitCast(@as(c_int, @truncate(@as(c_long, 4294967297))));
//     _ = &i;
// }
