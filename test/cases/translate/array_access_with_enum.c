typedef enum {
    one = 1,
    two = 2,
} EnumValues;

static inline int dynamic_array_access(EnumValues idx) {
  static const int values[] = {0, 1, 2};
  return values[idx - 1];
}

// translate
//
// pub fn dynamic_array_access(arg_idx: EnumValues) callconv(.c) c_int {
//     var idx = arg_idx;
//     _ = &idx;
//     const static_local_values = struct {
//         const values: [5]c_int = [5]c_int{
//             0,
//             1,
//             2,
//             3,
//             4,
//         };
//     };
//     _ = &static_local_values;
//     return static_local_values.values[idx -% @as(EnumValues, 1)];
// }
