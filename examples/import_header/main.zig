const std = @import("std");

const header = @import("header");

test "using my_add from Zig" {
    const res = header.my_add(30, header.MY_MACRO);
    try std.testing.expectEqual(42, res);
}
