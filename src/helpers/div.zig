const ArithmeticConversion = @import("arithmetic_conversion.zig").ArithmeticConversion;
const cast = @import("cast.zig").cast;
// BEGIN_SOURCE
pub fn div(a: anytype, b: anytype) ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
    const ResType = ArithmeticConversion(@TypeOf(a), @TypeOf(b));
    const a_casted = cast(ResType, a);
    const b_casted = cast(ResType, b);
    switch (@typeInfo(ResType)) {
        .float => return a_casted / b_casted,
        .int => return @divTrunc(a_casted, b_casted),
        else => unreachable,
    }
}
