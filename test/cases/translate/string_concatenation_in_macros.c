#define FOO "hello"
#define BAR FOO " world"
#define BAZ "oh, " FOO

// translate
// expect=fail
//
// pub const FOO = "hello";
//
// pub const BAR = FOO ++ " world";
//
// pub const BAZ = "oh, " ++ FOO;
