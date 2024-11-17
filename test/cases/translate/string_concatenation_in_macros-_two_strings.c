#define FOO "a" "b"
#define BAR FOO "c"

// translate
// expect=fail
//
// pub const FOO = "a" ++ "b";
//
// pub const BAR = FOO ++ "c";
