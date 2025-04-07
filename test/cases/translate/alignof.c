void main() {
    int a = _Alignof(int);
}
void foo() {
    int a = _Alignof 1;
}

// translate
//
// pub export fn main() void {
//     var a: c_int = @bitCast(@as(c_uint, @truncate(@alignOf(c_int))));
//     _ = &a;
// }
//
// pub export fn foo() void {
//     var a: c_int = @bitCast(@as(c_uint, @truncate(@alignOf(@TypeOf(@as(c_int, 1))))));
//     _ = &a;
// }
