pub inline fn __builtin_isinf(x: anytype) c_int {
    return @intFromBool(@import("std").math.isInf(x));
}
