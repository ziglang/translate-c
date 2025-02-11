struct comptime {
    int defer;
};

// translate
//
// pub const struct_comptime = extern struct {
//     @"defer": c_int = 0,
// };
// 
// pub const @"comptime" = struct_comptime;
