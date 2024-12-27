pub inline fn __has_builtin(func: anytype) c_int {
    _ = func;
    return @intFromBool(true);
}
