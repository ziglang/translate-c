int BAR = 0;
#define FOO -\
BAR

// translate
//
// pub inline fn FOO() @TypeOf(-BAR) {
//     return -BAR;
// }
