int BAR = 0;
#define FOO -\
BAR

// translate
// expect=fail
//
// pub inline fn FOO() @TypeOf(-BAR) {
//     return -BAR;
// }
