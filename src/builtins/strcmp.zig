pub inline fn __builtin_strcmp(s1: [*c]const u8, s2: [*c]const u8) c_int {
    return switch (@import("std").mem.orderZ(u8, s1, s2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}
