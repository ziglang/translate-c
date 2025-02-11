struct __attribute__((packed)) bar {
  short a;
  float b;
  double c;
  short x;
  float y;
  double z;
};

// translate
//
// pub const struct_bar = extern struct {
//     a: c_short align(1) = 0,
//     b: f32 align(1) = 0,
//     c: f64 align(1) = 0,
//     x: c_short align(1) = 0,
//     y: f32 align(1) = 0,
//     z: f64 align(1) = 0,
// };
