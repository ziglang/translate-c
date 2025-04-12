void somefunc(void) {
  int y;
  (void)({y=1; _Static_assert(1);});
}

// translate
//
// pub export fn somefunc() void {
//     var y: c_int = undefined;
//     _ = &y;
//     {
//         y = 1;
//         comptime {
//             if (!(@as(c_int, 1) != 0)) @compileError("static assertion failed");
//         };
//     }
// }
