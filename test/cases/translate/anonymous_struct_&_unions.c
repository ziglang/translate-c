typedef struct {
    union {
        char x;
        struct { int y; };
    };
} outer;
void foo(outer *x) { x->y = x->x; }

// translate
//
// const struct_unnamed_2 = extern struct {
//     y: c_int = 0,
// };
// const union_unnamed_1 = extern union {
//     x: u8,
//     unnamed_0: struct_unnamed_2,
// };
// pub const outer = extern struct {
//     unnamed_0: union_unnamed_1 = @import("std").mem.zeroes(union_unnamed_1),
//     pub const foo = __root.foo;
// };
// pub export fn foo(arg_x: [*c]outer) void {
//     var x = arg_x;
//     _ = &x;
//     x.*.unnamed_0.unnamed_0.y = x.*.unnamed_0.x;
// }
