#define FOO(X) __builtin_alloca_with_align((X), 8)

// translate
//
// pub const FOO = @compileError("unable to translate macro: undefined identifier `__builtin_alloca_with_align`");
