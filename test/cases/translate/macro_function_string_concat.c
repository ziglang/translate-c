#define bar() ""
#define FOO bar() "," bar()

// translate
// target=x86_64-linux
//
// pub inline fn bar() @TypeOf("") {
//     return "";
// }
// pub const FOO = bar() ++ "," ++ bar();
