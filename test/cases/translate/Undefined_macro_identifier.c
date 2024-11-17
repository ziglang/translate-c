#define FOO BAR

// translate
// expect=fail
//
// pub const FOO = @compileError("unable to translate macro: undefined identifier `BAR`");
