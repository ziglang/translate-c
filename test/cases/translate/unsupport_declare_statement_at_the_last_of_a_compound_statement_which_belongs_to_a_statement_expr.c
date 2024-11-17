void somefunc(void) {
  int y;
  (void)({y=1; _Static_assert(1);});
}

// translate
// expect=fail
//
// pub export fn somefunc() void {
//     var y: c_int = undefined;
//     _ = &y;
//     _ = blk: {
//         y = 1;
//     };
// }
