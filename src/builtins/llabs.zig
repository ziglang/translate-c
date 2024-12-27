/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn __builtin_llabs(val: c_longlong) c_longlong {
    return if (val == @import("std").math.minInt(c_longlong)) val else @intCast(@abs(val));
}
