void main() {
    int a = _Alignof(int);
}

// translate
// expect=fail
//
// pub export fn main() void {
//     var a: c_int = @as(c_int, @bitCast(@as(c_uint, @truncate(@alignOf(c_int)))));
//     _ = &a;
// }
