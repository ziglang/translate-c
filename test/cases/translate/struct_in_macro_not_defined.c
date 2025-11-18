#define FOO(x) x
#define BAR(x) struct FOO(x)

// translate
//
// pub const BAR = @compileError("unable to translate C expr: 'struct_FOO' not found");
