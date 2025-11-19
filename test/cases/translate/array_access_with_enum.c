typedef enum {
    one = 1,
    two = 2,
} EnumValues;

static inline int dynamic_array_access(EnumValues idx) {
  static const int values[] = {0, 1, 2};
  return values[idx - 1];
}

// translate
// target=native-linux
//
// pub const one: c_int = 1;
// pub const two: c_int = 2;
// pub const EnumValues = c_uint;
// pub fn dynamic_array_access(arg_idx: EnumValues) callconv(.c) c_int {
//     var idx = arg_idx;
//     _ = &idx;
//     const static_local_values = struct {
//         const values: [3]c_int = [3]c_int{
//             0,
//             1,
//             2,
//         };
//     };
//     _ = &static_local_values;
//     return static_local_values.values[idx -% @as(EnumValues, 1)];
// }
