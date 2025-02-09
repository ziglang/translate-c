const ArithmeticConversion = @import("arithmetic_conversion.zig").ArithmeticConversion;
const cast = @import("cast.zig").cast;
const signedRemainder = @import("signed_remainder.zig").signedRemainder;
// BEGIN_SOURCE
pub fn rem(a: anytype, b: anytype) ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
    const ResType = ArithmeticConversion(@TypeOf(a), @TypeOf(b));
    const a_casted = cast(ResType, a);
    const b_casted = cast(ResType, b);
    switch (@typeInfo(ResType)) {
        .int => {
            if (@typeInfo(ResType).int.signedness == .signed) {
                return signedRemainder(a_casted, b_casted);
            } else {
                return a_casted % b_casted;
            }
        },
        else => unreachable,
    }
}
