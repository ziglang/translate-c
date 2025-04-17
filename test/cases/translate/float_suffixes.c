#define foo 3.14f
#define bar 16.e-2l
#define FOO 0.12345
#define BAR .12345
#define baz 1e1
#define BAZ 42e-3f
#define foobar -73.L
extern const float my_float = 1.0f;
extern const double my_double = 1.0;
extern const long double my_longdouble = 1.0l;
extern const long double my_extended_precision_longdouble = 1.0000000000000003l;

// translate
//
// pub const foo = @as(f32, 3.14);
//
// pub const bar = @as(c_longdouble, 16.e-2);
//
// pub const FOO = @as(f64, 0.12345);
//
// pub const BAR = @as(f64, 0.12345);
//
// pub const baz = @as(f64, 1e1);
//
// pub const BAZ = @as(f32, 42e-3);
//
// pub const foobar = -@as(c_longdouble, 73);
//
// pub export const my_float: f32 = 1;
//
// pub export const my_double: f64 = 1;
//
// pub export const my_longdouble: c_longdouble = 1;
//
// pub export const my_extended_precision_longdouble: c_longdouble = 1.0000000000000002;
