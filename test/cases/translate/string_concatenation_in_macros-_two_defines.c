#define FOO "hello"
#define BAZ " world"
#define BAR FOO BAZ

// translate
// expect=fail
//
// pub const FOO = "hello";
//
// pub const BAZ = " world";
//
// pub const BAR = FOO ++ BAZ;