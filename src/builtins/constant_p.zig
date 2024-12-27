pub inline fn __builtin_constant_p(expr: anytype) c_int {
    _ = expr;
    return @intFromBool(false);
}
