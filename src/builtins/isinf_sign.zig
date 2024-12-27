/// Similar to isinf, except the return value is -1 for an argument of -Inf and 1 for an argument of +Inf.
pub inline fn __builtin_isinf_sign(x: anytype) c_int {
    if (!@import("std").math.isInf(x)) return 0;
    return if (@import("std").math.isPositiveInf(x)) 1 else -1;
}
