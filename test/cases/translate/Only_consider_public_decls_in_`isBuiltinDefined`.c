#define FOO std

// translate
// expect=fail
//
// pub const FOO = @compileError("unable to translate macro: undefined identifier `std`");
