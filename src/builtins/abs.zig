/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn __builtin_abs(val: c_int) c_int {
    return if (val == @import("std").math.minInt(c_int)) val else @intCast(@abs(val));
}
