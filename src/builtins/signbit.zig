pub inline fn __builtin_signbit(val: f64) c_int {
    return @intFromBool(@import("std").math.signbit(val));
}
