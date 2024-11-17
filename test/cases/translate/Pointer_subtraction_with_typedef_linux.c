typedef char* S;
void foo() {
    S a, b;
    long c = a - b;
}

// translate
// expect=fail
// target=native-linux
//
// pub export fn foo() void {
//     var a: S = undefined;
//     _ = &a;
//     var b: S = undefined;
//     _ = &b;
//     var c: c_long = @divExact(@as(c_long, @bitCast(@intFromPtr(a) -% @intFromPtr(b))), @sizeOf(u8));
//     _ = &c;
// }
