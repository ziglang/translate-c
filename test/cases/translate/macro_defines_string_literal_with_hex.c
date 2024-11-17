#define FOO "aoeu\xab derp"
#define FOO2 "aoeu\x0007a derp"
#define FOO_CHAR '\xfF'

// translate
// expect=fail
//
// pub const FOO = "aoeu\xab derp";
//
// pub const FOO2 = "aoeu\x7a derp";
//
// pub const FOO_CHAR = '\xff';
