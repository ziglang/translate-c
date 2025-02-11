struct {int x,y,z;} __attribute__((packed)) s0 = {1, 2};

// translate
//
// const struct_unnamed_1 = extern struct {
//     x: c_int align(1) = 0,
//     y: c_int align(1) = 0,
//     z: c_int align(1) = 0,
// };
// pub export var s0: struct_unnamed_1 = struct_unnamed_1{
//     .x = 1,
//     .y = 2,
//     .z = 0,
// };
