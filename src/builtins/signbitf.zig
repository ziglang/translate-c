pub inline fn __builtin_signbitf(val: f32) c_int {
    return @intFromBool(@import("std").math.signbit(val));
}
