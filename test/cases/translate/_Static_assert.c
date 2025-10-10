_Static_assert(1 == 1, "");

void my_function() {
    _Static_assert(2 + 2 * 2 == 6, "Math is hard");
}

// translate
//
// comptime {
//     if (!(@as(c_int, 1) == @as(c_int, 1))) @compileError("static assertion failed \"\"");
// }
// pub export fn my_function() void {
//     comptime {
//         if (!((@as(c_int, 2) + (@as(c_int, 2) * @as(c_int, 2))) == @as(c_int, 6))) @compileError("static assertion failed \"Math is hard\"");
//     }
// }
