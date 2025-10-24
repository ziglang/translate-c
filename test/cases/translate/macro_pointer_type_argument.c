typedef int Foo;

#define CAST(type, expr) ((type)(expr))
#define FOO_CAST(op) CAST(Foo*, (op))

// translate
//
// pub const Foo = c_int;
//
// pub const CAST = __helpers.CAST_OR_CALL;
// pub inline fn FOO_CAST(op: anytype) @TypeOf(CAST([*c]Foo, op)) {
//     _ = &op;
//     return CAST([*c]Foo, op);
// }
