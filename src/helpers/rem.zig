const __helpers = struct {
    const ArithmeticConversion = @import("arithmetic_conversion.zig").ArithmeticConversion;
    const cast = @import("cast.zig").cast;
    const signedRemainder = @import("signed_remainder.zig").signedRemainder;
};
// BEGIN_SOURCE
pub fn rem(a: anytype, b: anytype) __helpers.ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
    const ResType = __helpers.ArithmeticConversion(@TypeOf(a), @TypeOf(b));
    const a_casted = __helpers.cast(ResType, a);
    const b_casted = __helpers.cast(ResType, b);
    switch (@typeInfo(ResType)) {
        .int => {
            if (@typeInfo(ResType).int.signedness == .signed) {
                return __helpers.signedRemainder(a_casted, b_casted);
            } else {
                return a_casted % b_casted;
            }
        },
        else => unreachable,
    }
}
