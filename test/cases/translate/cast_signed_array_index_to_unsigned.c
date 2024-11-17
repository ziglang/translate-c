void foo() {
  int a[10], i = 0;
  a[i] = 0;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var a: [10]c_int = undefined;
//     _ = &a;
//     var i: c_int = 0;
//     _ = &i;
//     a[@as(c_uint, @intCast(i))] = 0;
// }
