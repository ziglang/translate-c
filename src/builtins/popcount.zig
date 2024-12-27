/// popcount of a c_uint will never exceed the capacity of a c_int
pub inline fn __builtin_popcount(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @popCount(val))));
}
