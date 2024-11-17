#define FOO _
int _ = 42;

// translate
// expect=fail
//
// pub inline fn FOO() @TypeOf(@"_") {
//     return @"_";
// }
//
// pub export var @"_": c_int = 42;
