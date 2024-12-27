/// Returns the number of trailing 0-bits in val, starting at the least significant bit position.
/// In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
pub inline fn __builtin_ctz(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @ctz(val))));
}
