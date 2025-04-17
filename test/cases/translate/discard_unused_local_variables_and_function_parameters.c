#define FOO(A, B) (A)
int bar(int x, int y) {
   return x;
}

// translate
//
// pub export fn bar(arg_x: c_int, arg_y: c_int) c_int {
//     var x = arg_x;
//     _ = &x;
//     var y = arg_y;
//     _ = &y;
//     return x;
// }
//
// pub inline fn FOO(A: anytype, B: anytype) @TypeOf(A) {
//     _ = &A;
//     _ = &B;
//     return A;
// }
