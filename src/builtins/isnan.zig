pub inline fn __builtin_isnan(x: anytype) c_int {
    return @intFromBool(@import("std").math.isNan(x));
}
