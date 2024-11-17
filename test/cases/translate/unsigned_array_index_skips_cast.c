void foo() {
  unsigned int a[10], i = 0;
  a[i] = 0;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var a: [10]c_uint = undefined;
//     _ = &a;
//     var i: c_uint = 0;
//     _ = &i;
//     a[i] = 0;
// }
