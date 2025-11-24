_Float16 a;
_Float32 b;
_Float64 c;
_Float128 d;

_Float32x e;
_Float64x f;
// _Float128x g; // unsupported on all targets

__fp16 h;
__bf16 i;
float j;
double k;
long double l;
__float128 m;

_Decimal32 n;
_Decimal64 o;
_Decimal128 p;
_Decimal64x q;

// translate
// target=x86_64-linux
//
// pub export var a: f16 = 0;
// pub export var b: f32 = 0;
// pub export var c: f64 = 0;
// pub export var d: f128 = 0;
// pub export var e: f64 = 0;
// pub export var f: c_longdouble = 0;
// pub export var h: f16 = 0;
// 
// pub const i = @compileError("unable to translate variable declaration type");
// 
// pub export var j: f32 = 0;
// pub export var k: f64 = 0;
// pub export var l: c_longdouble = 0;
// pub export var m: f128 = 0;
// 
// pub const n = @compileError("unable to translate variable declaration type");
// 
// pub const o = @compileError("unable to translate variable declaration type");
// 
// pub const p = @compileError("unable to translate variable declaration type");
// 
// pub const q = @compileError("unable to translate variable declaration type");
