#define FOO 0xf7p38
#define BAR -0X8F.BP5F
#define FOOBAR 0X0P+0
#define BAZ -0x.0a5dp+12
#define FOOBAZ 0xfE.P-1l

// translate
//
// pub const FOO = @as(f64, 0xf7p38);
//
// pub const BAR = -@as(f32, 0x8F.BP5);
//
// pub const FOOBAR = @as(f64, 0x0P+0);
//
// pub const BAZ = -@as(f64, 0x0.0a5dp+12);
//
// pub const FOOBAZ = @as(c_longdouble, 0xfE.P-1);
