void foo() {
  long long a[10], i = 0;
  a[i] = 0;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var a: [10]c_longlong = undefined;
//     _ = &a;
//     var i: c_longlong = 0;
//     _ = &i;
//     a[@as(usize, @intCast(i))] = 0;
// }
