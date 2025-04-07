void foo() {
  unsigned long long a[10], i = 0;
  a[i] = 0;
}

// translate
//
// pub export fn foo() void {
//     var a: [10]c_ulonglong = undefined;
//     _ = &a;
//     var i: c_ulonglong = 0;
//     _ = &i;
//     a[@intCast(i)] = 0;
// }
