/// Returns the number of leading 0-bits in x, starting at the most significant bit position.
/// In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
pub inline fn __builtin_clz(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @clz(val))));
}
