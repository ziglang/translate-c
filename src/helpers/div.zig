const __helpers = struct {
    const ArithmeticConversion = @import("arithmetic_conversion.zig").ArithmeticConversion;
    const cast = @import("cast.zig").cast;
};
// BEGIN_SOURCE
pub fn div(a: anytype, b: anytype) __helpers.ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
    const ResType = __helpers.ArithmeticConversion(@TypeOf(a), @TypeOf(b));
    const a_casted = __helpers.cast(ResType, a);
    const b_casted = __helpers.cast(ResType, b);
    switch (@typeInfo(ResType)) {
        .float => return a_casted / b_casted,
        .int => return @divTrunc(a_casted, b_casted),
        else => unreachable,
    }
}
