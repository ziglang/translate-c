const promoteIntLiteral = @import("promote_int_literal.zig").promoteIntLiteral;
// BEGIN_SOURCE
fn L_SUFFIX_ReturnType(comptime number: anytype) type {
    switch (@typeInfo(@TypeOf(number))) {
        .int, .comptime_int => return @TypeOf(promoteIntLiteral(c_long, number, .decimal)),
        .float, .comptime_float => return c_longdouble,
        else => @compileError("Invalid value for L suffix"),
    }
}
pub fn L_SUFFIX(comptime number: anytype) L_SUFFIX_ReturnType(number) {
    switch (@typeInfo(@TypeOf(number))) {
        .int, .comptime_int => return promoteIntLiteral(c_long, number, .decimal),
        .float, .comptime_float => @compileError("TODO: c_longdouble initialization from comptime_float not supported"),
        else => @compileError("Invalid value for L suffix"),
    }
}
