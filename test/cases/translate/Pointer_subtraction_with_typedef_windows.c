typedef char* S;
void foo() {
    S a, b;
    long long c = a - b;
}

// translate
// target=native-windows-msvc
//
// pub export fn foo() void {
//     var a: S = undefined;
//     _ = &a;
//     var b: S = undefined;
//     _ = &b;
//     var c: c_longlong = @divExact(@as(c_longlong, @bitCast(@intFromPtr(a) -% @intFromPtr(b))), @sizeOf(u8));
//     _ = &c;
// }
