const __helpers = struct {
    const promoteIntLiteral = @import("promote_int_literal.zig").promoteIntLiteral;
};
// BEGIN_SOURCE
pub fn U_SUFFIX(comptime n: comptime_int) @TypeOf(__helpers.promoteIntLiteral(c_uint, n, .decimal)) {
    return __helpers.promoteIntLiteral(c_uint, n, .decimal);
}
