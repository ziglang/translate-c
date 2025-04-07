void foo() {
  unsigned int a[10];
  _Bool i = 0;
  a[i] = 0;
}

// translate
//
// pub export fn foo() void {
//     var a: [10]c_uint = undefined;
//     _ = &a;
//     var i: bool = @as(c_int, 0) != 0;
//     _ = &i;
//     a[@intFromBool(i)] = 0;
// }
