void foo() {
  int a[10], i = 0;
  a[i] = 0;
}

// translate
//
// pub export fn foo() void {
//     var a: [10]c_int = undefined;
//     _ = &a;
//     var i: c_int = 0;
//     _ = &i;
//     a[@bitCast(@as(isize, @intCast(i)))] = 0;
// }
