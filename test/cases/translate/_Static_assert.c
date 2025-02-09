_Static_assert(1 == 1, "");

// translate
//
// comptime {
//     if (!(@as(c_int, 1) == @as(c_int, 1))) @compileError("static assertion failed \"\"");
// }
