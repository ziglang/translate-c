// Windows treats this as an enum with type c_int
enum EnumWithInits {
    VAL01 = 0,
    VAL02 = 1,
    VAL03 = 2,
    VAL04 = 3,
    VAL05 = -1,
    VAL06 = -2,
    VAL07 = -3,
    VAL08 = -4,
    VAL09 = VAL02 + VAL08,
    VAL10 = -1000012000,
    VAL11 = -1000161000,
    VAL12 = -1000174001,
    VAL13 = VAL09,
    VAL14 = VAL10,
    VAL15 = VAL11,
    VAL16 = VAL13,
    VAL17 = (VAL16 - VAL10 + 1),
    VAL18 = 0x1000000000000000L,
    VAL19 = VAL18 + VAL18 + VAL18 - 1,
    VAL20 = VAL19 + VAL19,
    VAL21 = VAL20 + 0xFFFFFFFFFFFFFFFF,
    VAL22 = 0xFFFFFFFFFFFFFFFF + 1,
    VAL23 = 0xFFFFFFFFFFFFFFFF,
};

// translate
// target=native-linux
//
// pub const VAL01: c_longlong = 0;
// pub const VAL02: c_longlong = 1;
// pub const VAL03: c_longlong = 2;
// pub const VAL04: c_longlong = 3;
// pub const VAL05: c_longlong = -1;
// pub const VAL06: c_longlong = -2;
// pub const VAL07: c_longlong = -3;
// pub const VAL08: c_longlong = -4;
// pub const VAL09: c_longlong = -3;
// pub const VAL10: c_longlong = -1000012000;
// pub const VAL11: c_longlong = -1000161000;
// pub const VAL12: c_longlong = -1000174001;
// pub const VAL13: c_longlong = -3;
// pub const VAL14: c_longlong = -1000012000;
// pub const VAL15: c_longlong = -1000161000;
// pub const VAL16: c_longlong = -3;
// pub const VAL17: c_longlong = 1000011998;
// pub const VAL18: c_longlong = 1152921504606846976;
// pub const VAL19: c_longlong = 3458764513820540927;
// pub const VAL20: c_longlong = 6917529027641081854;
// pub const VAL21: c_longlong = 6917529027641081853;
// pub const VAL22: c_longlong = 0;
// pub const VAL23: c_longlong = -1;
// pub const enum_EnumWithInits = c_longlong;
