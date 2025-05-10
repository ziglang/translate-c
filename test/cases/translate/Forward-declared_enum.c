extern enum enum_ty my_enum;
enum enum_ty { FOO };

// translate
// target=native-linux
//
// pub const FOO: c_int = 0;
// pub const enum_enum_ty = c_uint;
// pub extern var my_enum: enum_enum_ty;
