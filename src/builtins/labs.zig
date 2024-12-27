/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn __builtin_labs(val: c_long) c_long {
    return if (val == @import("std").math.minInt(c_long)) val else @intCast(@abs(val));
}
