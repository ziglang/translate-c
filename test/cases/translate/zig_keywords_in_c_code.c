struct comptime {
    int defer;
};

// translate
//
// pub const struct_comptime = extern struct {
//     @"defer": c_int = @import("std").mem.zeroes(c_int),
// };
// 
// pub const @"comptime" = struct_comptime;
