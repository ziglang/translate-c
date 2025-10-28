struct opaque;
struct opaque_2;
void function(struct opaque *opaque) {
    struct opaque_2 *cast = (struct opaque_2 *)opaque;
}

// translate
//
// pub const struct_opaque = opaque {
//     pub const function = __root.function;
// };
// pub const struct_opaque_2 = opaque {};
// pub export fn function(arg_opaque_1: ?*struct_opaque) void {
//     var opaque_1 = arg_opaque_1;
//     _ = &opaque_1;
//     var cast: ?*struct_opaque_2 = @ptrCast(@alignCast(opaque_1));
//     _ = &cast;
// }
