const promoteIntLiteral = @import("promote_int_literal.zig").promoteIntLiteral;
// BEGIN_SOURCE
pub fn UL_SUFFIX(comptime n: comptime_int) @TypeOf(promoteIntLiteral(c_ulong, n, .decimal)) {
    return promoteIntLiteral(c_ulong, n, .decimal);
}
