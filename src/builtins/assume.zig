pub inline fn __builtin_assume(cond: bool) void {
    if (!cond) unreachable;
}
