enum {
    One,
    Two,
};

// translate
// expect=fail
// target=native-linux
//
// pub const One: c_int = 0;
// pub const Two: c_int = 1;
// const enum_unnamed_1 = c_uint;
