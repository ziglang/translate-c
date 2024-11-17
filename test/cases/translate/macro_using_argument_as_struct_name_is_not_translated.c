#define FOO(x) struct x

// translate
// expect=fail
//
// pub const FOO = @compileError("unable to translate macro: untranslatable usage of arg `x`");
