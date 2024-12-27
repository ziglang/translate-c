pub inline fn __builtin_strlen(s: [*c]const u8) usize {
    return @import("std").mem.sliceTo(s, 0).len;
}
